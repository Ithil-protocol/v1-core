import { ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../src/types/Vault";
import type { MockWETH } from "../../src/types/MockWETH";

import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import {
  compareVaultStates,
  INITIAL_VAULT_STATE,
  expandTo18Decimals,
  expandToNDecimals,
  mintAndStake,
} from "../common/utils";
import { baseFee, fixedFee, minimumMargin } from "../common/params";

import { mockVaultFixture } from "../common/mockfixtures";
import { expect } from "chai";

describe("Lending unit tests", function () {
  const createFixtureLoader = waffle.createFixtureLoader;

  type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

  let wallet: Wallet, other: Wallet;

  let mockWETH: MockWETH;
  let admin: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;
  let createVault: ThenArg<ReturnType<typeof mockVaultFixture>>["createVault"];
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  let vault: Vault;
  let tokensAmount: BigNumber;

  describe("Lending integration tests", function () {
    before("create fixture loader", async () => {
      [wallet, other] = await (ethers as any).getSigners();
      loadFixture = createFixtureLoader([wallet, other]);
    });

    before("load fixtures", async () => {
      ({ mockWETH, admin, investor1, investor2, createVault } = await loadFixture(mockVaultFixture));
      vault = await createVault();
    });

    it("Vault: whitelistToken", async function () {
      const token = mockWETH.address;
      const initialState = await vault.vaults(token);

      // First, initial state is blank
      compareVaultStates(initialState, INITIAL_VAULT_STATE);

      // Whitelist
      await vault.whitelistToken(token, baseFee, fixedFee, minimumMargin);

      const finalState = await vault.vaults(token);

      const expectedState = {
        supported: true,
        locked: false,
        wrappedToken: finalState.wrappedToken,
        creationTime: finalState.creationTime,
        baseFee: BigNumber.from(baseFee),
        fixedFee: BigNumber.from(fixedFee),
        netLoans: BigNumber.from(0),
        insuranceReserveBalance: BigNumber.from(0),
        optimalRatio: BigNumber.from(0),
      };

      // Final state as expected
      compareVaultStates(finalState, expectedState);
    });

    it("Vault: stake and unstake tokens", async function () {
      const token = mockWETH;

      // Get wrapped token contract
      const wrappedTokenAddress = (await vault.vaults(token.address)).wrappedToken;
      const wrappedToken = await ethers.getContractAt(ERC20.abi, wrappedTokenAddress);

      expect(await wrappedToken.decimals()).to.equal(await token.decimals());

      // Amount to stake
      const amountToStake = expandTo18Decimals(1000);
      // Initial staker's liquidity
      const initialStakerLiquidity = expandTo18Decimals(10000);
      // Amount to unstake
      const amountBack = expandTo18Decimals(1000);

      const stakeTx = await mintAndStake(investor1, vault, token, initialStakerLiquidity, amountToStake);
      const stakeEvents = (await stakeTx.wait()).events;

      const middleState = {
        balance: await token.balanceOf(investor1.address),
        wrappedBalance: await wrappedToken.balanceOf(investor1.address),
      };

      expect(middleState.wrappedBalance).to.equal(amountToStake);

      const validStakeEvents = stakeEvents?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validStakeEvents?.length).equal(1);

      // Transfer tokens to vault: it has the same effect of fee generation
      const amountAdded = expandTo18Decimals(100);
      await token.mintTo(vault.address, amountAdded);

      // Withdrawing too much should revert
      await expect(vault.connect(investor1).unstake(token.address, amountToStake.add(amountAdded).add(1))).to.be
        .reverted;

      // Unstake maximum
      const unstakeTx = await vault.connect(investor1).unstake(token.address, amountBack.add(amountAdded));
      const unstakeEvents = (await unstakeTx.wait()).events;

      const finalState = {
        balance: await token.balanceOf(investor1.address),
      };

      expect(finalState.balance).to.equal(initialStakerLiquidity.sub(amountToStake).add(amountBack).add(amountAdded));

      const validUnstakeEvents = unstakeEvents?.filter(
        event => event.event === "Withdrawal" && event.args && event.args[0] === investor1.address,
      );
      expect(validUnstakeEvents?.length).equal(1);
    });

    it("Vault: stake and unstake ETH", async function () {
      const amount = ethers.utils.parseUnits("1.0", 18);
      const amountBack = ethers.utils.parseUnits("1.0", 18);

      const initialState = {
        balance: await waffle.provider.getBalance(investor1.address),
      };

      const stakeTx = await vault.connect(investor1).stakeETH(amount, { value: amount });
      const stakeEvents = await stakeTx.wait();

      const middleState = {
        balance: await waffle.provider.getBalance(investor1.address),
      };

      const totalGasForStaking = stakeEvents.gasUsed.mul(stakeEvents.effectiveGasPrice);

      expect(middleState.balance).to.equal(initialState.balance.sub(amount).sub(totalGasForStaking));

      const validStakeEvents = stakeEvents.events?.filter(
        event => event.event === "Deposit" && event.args && event.args[0] === investor1.address,
      );
      expect(validStakeEvents?.length).equal(1);

      const unstakeTx = await vault.connect(investor1).unstakeETH(amountBack);
      const unstakeEvents = await unstakeTx.wait();

      const finalState = {
        balance: await waffle.provider.getBalance(investor1.address),
      };

      const totalGasForUnstaking = unstakeEvents.gasUsed.mul(unstakeEvents.effectiveGasPrice);

      expect(finalState.balance).to.equal(middleState.balance.add(amount).sub(totalGasForUnstaking));

      const validUnstakeEvents = unstakeEvents.events?.filter(
        event => event.event === "Withdrawal" && event.args && event.args[0] === investor1.address,
      );
      expect(validUnstakeEvents?.length).equal(1);
    });

    it("Vault: addStrategy", async function () {
      const strategy = "0x0000000000000000000000000000000000000000"; // use null as mock strategy address

      const initialState = {
        strategyAdded: await vault.strategies(strategy),
      };

      const rsp = await vault.addStrategy(strategy);
      const events = (await rsp.wait()).events;

      const finalState = {
        strategyAdded: await vault.strategies(strategy),
      };

      expect(initialState.strategyAdded).to.equal(false);
      expect(finalState.strategyAdded).to.equal(true);

      const validEvents = events?.filter(
        event => event.event === "StrategyWasAdded" && event.args && event.args[0] === strategy,
      );
      expect(validEvents?.length).to.equal(1);
    });

    it("Vault: removeStrategy", async function () {
      const strategy = "0x0000000000000000000000000000000000000000"; // use null as mock strategy address

      await vault.addStrategy(strategy);

      const initialState = {
        strategyAdded: await vault.strategies(strategy),
      };

      const rsp = await vault.removeStrategy(strategy);
      const events = (await rsp.wait()).events;

      const finalState = {
        strategyAdded: await vault.strategies(strategy),
      };

      expect(initialState.strategyAdded).to.equal(true);
      expect(finalState.strategyAdded).to.equal(false);

      const validEvents = events?.filter(
        event => event.event === "StrategyWasRemoved" && event.args && event.args[0] === strategy,
      );
      expect(validEvents?.length).to.equal(1);
    });
    // checkTreasuryStaking();
    // checkRebalanceInsurance();
    it("Vault: claimable", async function () {
      // Initial status
      const initialClaimable = await vault.connect(investor1).claimable(mockWETH.address);
      expect(initialClaimable).to.equal(0);

      // Stake and check claimable value
      const amountToStake = expandToNDecimals(1000, 18);
      const initialStakerLiquidity = expandToNDecimals(10000, 18);
      await mintAndStake(investor1, vault, mockWETH, initialStakerLiquidity, amountToStake);

      const claimable = await vault.connect(investor1).claimable(mockWETH.address);

      expect(claimable).to.equal(amountToStake);
    });
    it("Vault: toggle lock", async function () {
      // Initial status should be unlocked
      const initialLock = (await vault.vaults(mockWETH.address)).locked;
      expect(initialLock).to.equal(false);

      // Toggle lock
      await vault.toggleLock(true, mockWETH.address);

      // Final status should be locked
      const finalLock = (await vault.vaults(mockWETH.address)).locked;
      expect(finalLock).to.equal(true);
    });
    // checkBorrow(); // borrow, repay // TODO: currently, skip borrow checking because it is strategyOnly
  });
});
