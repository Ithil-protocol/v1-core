import { expect } from "chai";

import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { tokens } from "../../common/mainnet";
import { getTokens, matchState } from "../../common/utils";

import type { ERC20 } from "../../../src/types/ERC20";
import { ERC20Permit } from "../../../src/types/ERC20Permit";
import type { Vault } from "../../../src/types/Vault";
import type { Artifact } from "hardhat/types";

import { vaultFixture } from "../../common/fixtures";
import { getPermitSignature } from "../../common/permit";
import { amount, baseFee, fixedFee, marginTokenLiquidity, minimumMargin, stakedValue } from "../../common/params";

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

  after("give tokens back to whale", async () => {
    const investor1Amount = await WETH.balanceOf(investor1.address);
    await WETH.connect(investor1).transfer(tokens.WETH.whale, investor1Amount);
    const investor2Amount = await WETH.balanceOf(investor2.address);
    await WETH.connect(investor2).transfer(tokens.WETH.whale, investor2Amount);
  });

  describe("Base functions", function () {
    let vaultState;
    let wrappedWETH: ERC20;
    it("Vault: whitelist WETH", async function () {
      await vault.whitelistToken(WETH.address, baseFee, fixedFee, minimumMargin);
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
      await expect(vault.whitelistToken(WETH.address, baseFee, fixedFee, minimumMargin)).to.be.reverted;
    });

    it("Vault: stake WETH", async function () {
      const rsp = await vault.connect(investor1).stake(WETH.address, stakedValue);
      expect(await vault.balance(WETH.address)).to.equal(stakedValue);
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(stakedValue));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(stakedValue);

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: stake again", async function () {
      const rsp = await vault.connect(investor1).stake(WETH.address, 1);
      expect(await vault.balance(WETH.address)).to.equal(stakedValue.add(1));
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(stakedValue.add(1)));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(stakedValue.add(1));

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: unstake WETH", async function () {
      const rsp = await vault.connect(investor1).unstake(WETH.address, stakedValue);
      expect(await vault.balance(WETH.address)).to.equal(1);
      expect(await WETH.balanceOf(investor1.address)).to.equal(tokensAmount.sub(1));
      expect(await wrappedWETH.balanceOf(investor1.address)).to.equal(1);

      const events = (await rsp.wait()).events;
      const validEvents = events?.filter(
        event => event.event === "Withdrawal" && event.args && event.args[0] === investor1.address,
      );
      expect(validEvents?.length).equal(1);
    });

    it("Vault: unstake again", async function () {
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
      await vault.connect(investor1).stake(WETH.address, amountToStake);
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

    it("Vault: booster tries to remove fees", async function () {
      const amountToBoost = BigNumber.from(10);
      const amountToStake = BigNumber.from(10);
      const feeAmount = BigNumber.from(2);
      // boost 10 tokens
      await vault.connect(investor2).boost(WETH.address, amountToBoost);
      // stake 10 tokens
      await vault.connect(investor1).stake(WETH.address, amountToStake);
      // Generate fees by transfer
      await WETH.connect(investor1).transfer(vault.address, feeAmount);

      // Booster unboosting of higher amount should revert
      await expect(vault.connect(investor2).unboost(WETH.address, amountToBoost.add(1))).to.be.reverted;
      // Booster unstaking of any amount should revert
      expect(await vault.connect(investor2).claimable(WETH.address)).to.equal(0);
      await expect(vault.connect(investor2).unstake(WETH.address, 1)).to.be.reverted;
      // Investor 1 can unstake
      await vault.connect(investor1).unstake(WETH.address, amountToStake.add(feeAmount));
      // Booster can unboost
      await vault.connect(investor2).unboost(WETH.address, amountToBoost);
    });

    it("Vault: enable and disable OUSD feature", async function () {
      await vault.toggleOusdRebase(true);
      await vault.toggleOusdRebase(false);
    });

    //TODO: other tests with investor1 and investor2 interlacing
  });

  it("Vault: stake with permit", async function () {
    const ohmAmount = BigNumber.from(10**9);

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20Permit");
    let ohm = <ERC20Permit>await ethers.getContractAt(tokenArtifact.abi, tokens.OHM.address);
    await vault.whitelistToken(ohm.address, baseFee, fixedFee, ohmAmount);

    const { v, r, s } = await getPermitSignature(wallet, ohm, vault.address);//, ohmAmount);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20;

    expect(await ohm.allowance(wallet.address, vault.address)).to.be.eq(0);
    await vault.connect(wallet.address).stakeWithPermit(ohm.address, ohmAmount, deadline, v, r, s);
    await vault.connect(wallet.address).unstake(ohm.address, ohmAmount);
  });
});
