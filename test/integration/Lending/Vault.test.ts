import { expect } from "chai";

import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { tokens } from "../../common/mainnet";
import { getTokens, matchState, expandToNDecimals } from "../../common/utils";

import type { ERC20 } from "../../../src/types/ERC20";
import type { Vault } from "../../../src/types/Vault";
import type { Artifact } from "hardhat/types";

import { vaultFixture } from "../../common/fixtures";

import { amount, baseFee, fixedFee, minimumMargin, stakingCap } from "../../common/params";
import { WritableStream } from "stream/web";

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let WETH: ERC20;
let admin: SignerWithAddress;
let investor1: SignerWithAddress;
let investor2: SignerWithAddress;
let createVault: ThenArg<ReturnType<typeof vaultFixture>>["createVault"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let tokensAmount: BigNumber;

describe("Lending integration tests", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ WETH, admin, investor1, investor2, createVault } = await loadFixture(vaultFixture));
    vault = await createVault();
  });

  before("get tokens", async () => {
    tokensAmount = await WETH.balanceOf(tokens.WETH.whale);
    await getTokens(investor1.address, WETH.address, tokens.WETH.whale, tokensAmount);
    await WETH.connect(investor1).approve(vault.address, tokensAmount);
    expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount);
  });

  describe("Base functions", function () {
    let vaultState;
    let wrappedWETH: ERC20;
    it("Vault: whitelist WETH", async function () {
      await vault.whitelistToken(WETH.address, baseFee, fixedFee, minimumMargin, stakingCap);
      const state = await vault.vaults(WETH.address);
      vaultState = state;
      matchState(
        vaultState,
        true,
        false,
        baseFee,
        fixedFee,
        BigNumber.from(0),
        minimumMargin,
        stakingCap,
        BigNumber.from(0),
        BigNumber.from(0),
      );
      const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
      wrappedWETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, vaultState.wrappedToken);
    });

    it("Vault: edit minimum margin", async function () {
      await vault.connect(admin).editMinimumMargin(WETH.address, minimumMargin.add(1));
      vaultState = await vault.vaults(WETH.address);
      expect(vaultState.minimumMargin).to.equal(minimumMargin.add(1));
    });

    it("Vault: whitelist already whitelisted", async function () {
      await expect(vault.whitelistToken(WETH.address, baseFee, fixedFee, minimumMargin, stakingCap)).to.be.reverted;
    });

    it("Vault: stake WETH", async function () {
      const rsp = await vault.connect(investor1).stake(WETH.address, stakingCap);
      expect(await vault.balance(WETH.address)).to.equal(stakingCap);
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(stakingCap));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(stakingCap);

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: stake more than cap", async function () {
      await expect(vault.connect(investor1).stake(WETH.address, 1)).to.be.reverted;
    });

    it("Vault: edit cap", async function () {
      await vault.connect(admin).editCap(WETH.address, stakingCap.add(1));
    });

    it("Vault: stake again", async function () {
      const rsp = await vault.connect(investor1).stake(WETH.address, 1);
      expect(await vault.balance(WETH.address)).to.equal(stakingCap.add(1));
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(stakingCap.add(1)));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(stakingCap.add(1));

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: unstake WETH", async function () {
      const rsp = await vault.connect(investor1).unstake(WETH.address, stakingCap);
      expect(await vault.balance(WETH.address)).to.equal(1);
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(1));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(1);

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Withdrawal" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: decrease staking cap when tokens are still staked and try to stake", async function () {
      await vault.connect(admin).editCap(WETH.address, stakingCap.sub(1));
      await expect(vault.connect(investor1).stake(WETH.address, stakingCap.sub(1))).to.be.reverted;
    });

    it("Vault: unstake after staking cap is decreased", async function () {
      const rsp = await vault.connect(investor1).unstake(WETH.address, 1);
      expect(await vault.balance(WETH.address)).to.equal(0);
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount);
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(0);

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Withdrawal" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: boost liquidity", async function () {
      // Now investor1 is the whale: give a bunch of tokens to investor2
      tokensAmount = await WETH.balanceOf(investor1.address);
      await WETH.connect(investor1).transfer(investor2.address, tokensAmount.div(2));
      await WETH.connect(investor2).approve(vault.address, tokensAmount.div(2));

      const amountToBoost = BigNumber.from(10);
      // boost 10 tokens
      await vault.connect(investor2).boost(WETH.address, amountToBoost);
      expect(await WETH.balanceOf(investor2.address)).to.equal(tokensAmount.div(2).sub(amountToBoost));
      expect((await vault.vaults(WETH.address)).boostedAmount).to.equal(amountToBoost);
      expect(await vault.boosters(investor2.address, WETH.address)).to.equal(amountToBoost);
    });

    it("Vault: stake after boosting", async function () {
      const amountToStake = BigNumber.from(10);
      const rsp = await vault.connect(investor1).stake(WETH.address, amountToStake);
      // investor1 cannot unstake more even if there is the boost in place
      await expect(vault.connect(investor1).unstake(WETH.address, amountToStake.add(1))).to.be.reverted;
    });

    it("Vault: remove boosting amount", async function () {
      const investor2Balance = await WETH.balanceOf(investor2.address);
      const boosted = await vault.boosters(investor2.address, WETH.address);
      await vault.connect(investor2).unboost(WETH.address, boosted);
      expect(await WETH.balanceOf(investor2.address)).to.equal(investor2Balance.add(boosted));
      expect((await vault.vaults(WETH.address)).boostedAmount).to.equal(0);
      expect(await vault.boosters(investor2.address, WETH.address)).to.equal(0);
    });

    it("Vault: whitelist OUSD", async function () {
      const OUSD = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
      let ABI =
        '[{"inputs": [],"name": "rebaseOptIn","outputs": [],"stateMutability": "nonpayable","type": "function"}]';
      let iface = new ethers.utils.Interface(ABI);
      const data = iface.encodeFunctionData("rebaseOptIn");
      await vault.whitelistTokenAndExec(OUSD, baseFee, fixedFee, ethers.utils.parseEther("100000"), stakingCap, data);

      const state = await vault.vaults(OUSD);
      vaultState = state;
      matchState(
        vaultState,
        true,
        false,
        baseFee,
        fixedFee,
        BigNumber.from(0),
        expandToNDecimals(100000, 18),
        stakingCap,
        BigNumber.from(0),
        BigNumber.from(0),
      );
    });
  });

  //TODO: other tests with investor1 and investor2 interlacing
});
