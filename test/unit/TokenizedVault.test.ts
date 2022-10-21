import { network, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { TokenizedVault } from "../../src/types/TokenizedVault";
import type { MockToken } from "../../src/types/MockToken";
import { tokenizedVaultFixture } from "../common/mockfixtures";
import exp from "constants";

describe("Tokenized Vault tests", function () {
  const createFixtureLoader = waffle.createFixtureLoader;

  type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

  let wallet: Wallet, other: Wallet;

  let native: MockToken;
  let admin: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;
  let createVault: ThenArg<ReturnType<typeof tokenizedVaultFixture>>["createVault"];
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  let vault: TokenizedVault;

  before("load fixture", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
    ({ native, admin, investor1, investor2, createVault } = await loadFixture(tokenizedVaultFixture));
    vault = await createVault();
  });

  describe("Deployment", function () {
    describe("Validations", function () {
      it("Vault decimals should be the same as native's one", async function () {
        const vaultDecimals = await vault.decimals();
        const nativeDecimals = await native.decimals();
        expect(vaultDecimals).to.equal(nativeDecimals);
      });

      it("Vault name should be 'Ithil {nativeName}'", async function () {
        const vaultName = await vault.name();
        const expectedName = "Ithil " + (await native.name());
        expect(vaultName).to.equal(expectedName);
      });

      it("Vault symbol should be 'i{nativeSymbol}'", async function () {
        const vaultSymbol = await vault.symbol();
        const expectedSymbol = "i" + (await native.symbol());
        expect(vaultSymbol).to.equal(expectedSymbol);
      });

      it("Creation time should be of the previous block", async function () {
        const creationTime = await vault.creationTime();
        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        const timestampBefore = BigNumber.from(blockBefore.timestamp);
        expect(creationTime).to.equal(timestampBefore);
      });
    });
  });

  describe("Security", function () {
    describe("Validations", function () {
      it("Non owner cannot toggle lock", async function () {
        await expect(vault.connect(investor2).toggleLock()).to.be.reverted;
      });

      it("Owner can toggle lock", async function () {
        const initialLock = await vault.locked();
        await vault.connect(admin).toggleLock();
        expect(await vault.locked()).to.equal(!initialLock);
      });

      it("Non owner cannot change unlock time", async function () {
        await expect(vault.connect(investor2).setUnlockTime(BigNumber.from(1000))).to.be.reverted;
      });

      it("Change unlock time", async function () {
        await vault.connect(admin).setUnlockTime(BigNumber.from(1000));
        expect(await vault.unlockTime()).to.equal(BigNumber.from(1000));
      });
    });
    describe("Events", function () {});
  });

  describe("Assets", function () {
    let amountToDeposit: BigNumber;
    before("Mint and approve to investor", async () => {
      await native.connect(investor1).mint();
      amountToDeposit = await native.balanceOf(investor1.address);
      await native.connect(investor1).approve(vault.address, amountToDeposit);
    });

    describe("Validations", function () {
      it("Asset token should be the same as the constructor", async function () {
        const nativeToken = await vault.asset();
        expect(nativeToken).to.equal(native.address);
      });

      it("Locked vault should not allow to deposit and mint", async function () {
        // Lock vault
        if (!(await vault.locked())) await vault.connect(admin).toggleLock();

        await expect(vault.connect(investor1).deposit(amountToDeposit, investor1.address)).to.be.revertedWith(
          "ERROR_Vault__Locked()",
        );
        await expect(vault.connect(investor1).mint(amountToDeposit, investor1.address)).to.be.revertedWith(
          "ERROR_Vault__Locked()",
        );

        // Unlock vault to proceed with other tests
        await vault.connect(admin).toggleLock();
      });

      it("Non admin cannot boost", async function () {
        await expect(vault.connect(investor1).boost(investor1.address, amountToDeposit)).to.be.revertedWith(
          "Ownable: caller is not the owner",
        );
      });
    });

    describe("Deposit and withdraw", function () {
      it("Deposit assets", async function () {
        const sharesToObtain = await vault.previewDeposit(amountToDeposit);
        await vault.connect(investor1).deposit(amountToDeposit, investor1.address);
        expect(await vault.totalAssets()).to.equal(amountToDeposit);
        expect(await vault.balanceOf(investor1.address)).to.equal(sharesToObtain);
      });

      it("Third party cannot withdraw on behalf of investor", async function () {
        await expect(vault.connect(admin).withdraw(amountToDeposit, investor1.address, investor1.address)).to.be
          .reverted;
      });

      it("Withdraw assets", async function () {
        const assetsToObtain = await vault.previewWithdraw(amountToDeposit);
        await vault.connect(investor1).withdraw(amountToDeposit, investor1.address, investor1.address);
        expect(await vault.totalAssets()).to.equal(0);
        expect(await native.balanceOf(investor1.address)).to.equal(assetsToObtain);
      });

      it("Mint assets", async function () {
        const sharesToObtain = await vault.previewDeposit(amountToDeposit);
        // Need to re-approve because previous approval is used
        await native.connect(investor1).approve(vault.address, amountToDeposit);
        await vault.connect(investor1).mint(sharesToObtain, investor1.address);
        expect(await vault.totalAssets()).to.equal(amountToDeposit);
        expect(await vault.balanceOf(investor1.address)).to.equal(sharesToObtain);
      });

      it("Third party cannot redeem on behalf of investor1", async function () {
        const sharesToObtain = await vault.balanceOf(investor1.address);
        await expect(vault.connect(admin).redeem(sharesToObtain, investor1.address, investor1.address)).to.be.reverted;
      });

      it("Redeem assets", async function () {
        const sharesToRedeem = await vault.balanceOf(investor1.address);
        const assetsToObtain = await vault.previewRedeem(sharesToRedeem);
        await vault.connect(investor1).redeem(sharesToRedeem, investor1.address, investor1.address);
        expect(await vault.totalAssets()).to.equal(0);
        expect(await native.balanceOf(investor1.address)).to.equal(assetsToObtain);
      });

      it("Deposit and transfer shares to a third party", async function () {
        const sharesToObtain = await vault.previewDeposit(amountToDeposit);
        // Need to re-approve because previous approval is used
        await native.connect(investor1).approve(vault.address, amountToDeposit);
        await vault.connect(investor1).deposit(amountToDeposit, investor2.address);
        expect(await vault.totalAssets()).to.equal(amountToDeposit);
        expect(await vault.balanceOf(investor2.address)).to.equal(sharesToObtain);
      });

      it("Third party withdraws assets", async function () {
        const assetsToObtain = await vault.previewWithdraw(amountToDeposit);
        await vault.connect(investor2).withdraw(amountToDeposit, investor1.address, investor2.address);
        expect(await vault.totalAssets()).to.equal(0);
        expect(await native.balanceOf(investor1.address)).to.equal(assetsToObtain);
      });

      it("Mint and transfer shares to a third party", async function () {
        const sharesToObtain = await vault.previewDeposit(amountToDeposit);
        // Need to re-approve because previous approval is used
        await native.connect(investor1).approve(vault.address, amountToDeposit);
        await vault.connect(investor1).mint(sharesToObtain, investor2.address);
        expect(await vault.totalAssets()).to.equal(amountToDeposit);
        expect(await vault.balanceOf(investor2.address)).to.equal(sharesToObtain);
      });

      it("Third party approves investor which then redeems the shares", async function () {
        const sharesToRedeem = await vault.balanceOf(investor2.address);
        const assetsToObtain = await vault.previewRedeem(sharesToRedeem);
        expect(await vault.allowance(investor2.address, investor1.address)).to.equal(0);
        await expect(vault.connect(investor1).redeem(sharesToRedeem, investor1.address, investor2.address)).to.be
          .reverted;
        // investor2 approves investor
        await vault.connect(investor2).approve(investor1.address, sharesToRedeem);
        await vault.connect(investor1).redeem(sharesToRedeem, investor1.address, investor2.address);
        expect(await vault.totalAssets()).to.equal(0);
        expect(await native.balanceOf(investor1.address)).to.equal(assetsToObtain);
      });
    });

    describe("Boosting", function () {
      let amountToBoost: BigNumber;
      before("Refill tokens to admin", async () => {
        await native.connect(admin).mint();
        amountToBoost = await native.balanceOf(admin.address);
        expect(amountToBoost).to.be.above(0);
      });

      it("Boost", async function () {
        const initialBoostAmount = (await vault.vaultAccounting()).boostedAmount;
        const initialAdminBalance = await native.balanceOf(admin.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialAssets = await vault.totalAssets();

        // Fail without approval

        await expect(vault.connect(admin).boost(admin.address, amountToBoost)).to.be.revertedWith(
          "ERC20: insufficient allowance",
        );

        await native.connect(admin).approve(vault.address, amountToBoost);
        await vault.connect(admin).boost(admin.address, amountToBoost);
        // Boosted amount increased
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.add(amountToBoost));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(amountToBoost));
        // Admin balance decreased
        expect(await native.balanceOf(admin.address)).to.equal(initialAdminBalance.sub(amountToBoost));
        // Assets stay constant
        expect(await vault.totalAssets()).to.equal(initialAssets);
      });

      it("Boost on behalf of investor1", async function () {
        // Refill tokens to investor
        await native.connect(investor1).mint();

        const initialAdminBalance = await native.balanceOf(admin.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialAssets = await vault.totalAssets();
        const initialInvestorBalance = await native.balanceOf(investor1.address);
        const initialBoostAmount = (await vault.vaultAccounting()).boostedAmount;

        // Fail without approval

        await expect(vault.connect(admin).boost(investor1.address, initialInvestorBalance)).to.be.revertedWith(
          "ERC20: insufficient allowance",
        );

        await native.connect(investor1).approve(vault.address, initialInvestorBalance);
        await vault.connect(admin).boost(investor1.address, initialInvestorBalance);

        // Boosted amount increased
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.add(initialInvestorBalance));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(initialInvestorBalance));
        // Investor balance decreased
        expect(await native.balanceOf(investor1.address)).to.equal(initialInvestorBalance.sub(initialInvestorBalance));
        // Admin balance stay constant
        expect(await native.balanceOf(admin.address)).to.equal(initialAdminBalance);
        // Assets stay constant
        expect(await vault.totalAssets()).to.equal(initialAssets);
      });

      it("Unboost", async function () {
        const initialBoostAmount = (await vault.vaultAccounting()).boostedAmount;
        const initialAdminBalance = await native.balanceOf(admin.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialAssets = await vault.totalAssets();
        await vault.connect(admin).unboost(admin.address, amountToBoost);
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.sub(amountToBoost));

        // Boosted amount decreased
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.sub(amountToBoost));
        // Vault balance decreased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.sub(amountToBoost));
        // Admin balance increased
        expect(await native.balanceOf(admin.address)).to.equal(initialAdminBalance.add(amountToBoost));
        // Assets stay constant
        expect(await vault.totalAssets()).to.equal(initialAssets);
      });

      it("Unboost on behalf of investor1", async function () {
        const initialAdminBalance = await native.balanceOf(admin.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialAssets = await vault.totalAssets();
        const initialInvestorBalance = await native.balanceOf(investor1.address);
        const initialBoostAmount = (await vault.vaultAccounting()).boostedAmount;
        const toUnboost = initialBoostAmount.div(2);

        // Unboos and give to investor1
        await vault.connect(admin).unboost(investor1.address, toUnboost);

        // Boosted amount decreased
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.sub(toUnboost));
        // Vault balance decreased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.sub(toUnboost));
        // Investor balance increased
        expect(await native.balanceOf(investor1.address)).to.equal(initialInvestorBalance.add(toUnboost));
        // Admin balance stays constant
        expect(await native.balanceOf(admin.address)).to.equal(initialAdminBalance);
        // Assets stay constant
        expect(await vault.totalAssets()).to.equal(initialAssets);
      });

      it("Unboost more than current boosting", async function () {
        const initialBoostAmount = (await vault.vaultAccounting()).boostedAmount;
        const initialAdminBalance = await native.balanceOf(admin.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const amountToUnboost = initialBoostAmount.add(1);
        const initialAssets = await vault.totalAssets();

        await vault.connect(admin).unboost(admin.address, amountToUnboost);

        let expectedUnboost;
        if (amountToUnboost.lte(initialBoostAmount)) expectedUnboost = amountToUnboost;
        else expectedUnboost = initialBoostAmount;

        // Boosted amount decreased to zero (no loans at this point)
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(initialBoostAmount.sub(expectedUnboost));
        // Vault balance decreased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.sub(expectedUnboost));
        // Admin balance increased
        expect(await native.balanceOf(admin.address)).to.equal(initialAdminBalance.add(expectedUnboost));
        // Assets stay constant
        expect(await vault.totalAssets()).to.equal(initialAssets);
      });
    });

    describe("Borrow and repay", function () {
      let initialShares: BigNumber;
      let initialAssets: BigNumber;
      before("Start with an unboosted, filled vault", async () => {
        const initialBoostedAmount = (await vault.vaultAccounting()).boostedAmount;
        if (initialBoostedAmount.gt(0)) await vault.connect(admin).unboost(admin.address, initialBoostedAmount);
        expect((await vault.vaultAccounting()).boostedAmount).to.equal(0);
        expect(await vault.totalAssets()).to.equal(0);

        // Refill investor1 and deposit
        await native.connect(investor1).mint();
        const amountToDeposit = await native.balanceOf(investor1.address);

        await native.connect(investor1).approve(vault.address, amountToDeposit);
        await vault.connect(investor1).deposit(amountToDeposit, investor1.address);
        expect(await vault.totalAssets()).to.equal(amountToDeposit);
        initialShares = await vault.balanceOf(investor1.address);
        initialAssets = amountToDeposit;
      });

      it("Non owner cannot borrow", async function () {
        await expect(vault.connect(investor1).borrow(BigNumber.from(1), investor1.address)).to.be.revertedWith(
          "Ownable: caller is not the owner",
        );
      });

      it("Borrow assets", async function () {
        // Borrow half of the assets and give them to investor2
        const toBorrow = initialAssets.div(2);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialInvestorBalance = await native.balanceOf(investor2.address);
        const initialTotalAssets = await vault.totalAssets();

        await vault.connect(admin).borrow(toBorrow, investor2.address);
        // Net loans increased
        expect((await vault.vaultAccounting()).netLoans).to.equal(toBorrow);
        // Investor2 balance increased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.add(toBorrow));
        // Vault balance decreased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.sub(toBorrow));
        // Vault assets stay constant
        expect(await vault.totalAssets()).to.equal(initialTotalAssets);
      });

      it("Non owner cannot repay", async function () {
        await expect(
          vault.connect(investor2).repay(BigNumber.from(1), BigNumber.from(1), investor2.address),
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      let fees: BigNumber;
      let expectedUnlock: BigNumber;

      it("Repay assets with a gain", async function () {
        // Refill investor2 (which is also the "strategy")
        await native.connect(investor2).mint();
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialInvestorBalance = await native.balanceOf(investor2.address);
        const initialTotalAssets = await vault.totalAssets();
        const currentLoans = (await vault.vaultAccounting()).netLoans;
        // Repay half of the loans + 10% fees
        const debtToRepay = currentLoans.div(2);
        fees = currentLoans.div(10);

        // Fail without approval

        await expect(
          vault.connect(admin).repay(debtToRepay.add(fees), debtToRepay, investor2.address),
        ).to.be.revertedWith("ERC20: insufficient allowance");

        // Approve vault for repay
        await native.connect(investor2).approve(vault.address, debtToRepay.add(fees));
        await vault.connect(admin).repay(debtToRepay.add(fees), debtToRepay, investor2.address);

        // Net loans decreased
        expect((await vault.vaultAccounting()).netLoans).to.equal(currentLoans.sub(debtToRepay));
        // Investor2 balance decreased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.sub(debtToRepay.add(fees)));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(debtToRepay.add(fees)));
        // Current profits increased
        expect((await vault.vaultAccounting()).currentProfits).to.equal(fees);
        // Vault assets stay constant
        expect(await vault.totalAssets()).to.equal(initialTotalAssets);
      });

      it("Check fees unlocking", async function () {
        const initialTotalAssets = await vault.totalAssets();
        // Unlock half of the fees after half unlock time
        const unlockTime = await vault.unlockTime();
        const latestRepay = (await vault.vaultAccounting()).latestRepay;
        let nextTimestapm = parseInt(latestRepay.add(unlockTime.div(2)).toString());
        await network.provider.send("evm_setNextBlockTimestamp", [nextTimestapm]);
        await network.provider.send("evm_mine");

        // Fees should be unlocked
        expectedUnlock = BigNumber.from(nextTimestapm).sub(latestRepay).mul(fees).div(unlockTime);
        expect(await vault.totalAssets()).to.equal(initialTotalAssets.add(expectedUnlock));
      });

      it("Repay assets with a loss, coverable with locked fees", async function () {
        const unlockTime = await vault.unlockTime();
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialInvestorBalance = await native.balanceOf(investor2.address);
        const currentLoans = (await vault.vaultAccounting()).netLoans;
        const currentProfits = (await vault.vaultAccounting()).currentProfits;
        const latestRepay = (await vault.vaultAccounting()).latestRepay;

        const expectedLockedProfits = currentProfits.sub(expectedUnlock);
        // Repay half of the loans with a 10% loss
        const debtToRepay = currentLoans.div(2);
        const loss = expectedLockedProfits.div(2);

        // Fail without approval

        await expect(
          vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address),
        ).to.be.revertedWith("ERC20: insufficient allowance");

        // Approve vault for repay
        await native.connect(investor2).approve(vault.address, debtToRepay.sub(loss));
        await vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address);

        // Net loans decreased
        expect((await vault.vaultAccounting()).netLoans).to.equal(currentLoans.sub(debtToRepay));
        // Investor2 balance decreased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.sub(debtToRepay.sub(loss)));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(debtToRepay.sub(loss)));
        // Current profits decrease
        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        const timestampBefore = BigNumber.from(blockBefore.timestamp);
        const unlockedProfits = timestampBefore.sub(latestRepay).mul(currentProfits).div(unlockTime);
        const lockedProfits = currentProfits.sub(unlockedProfits);
        expect((await vault.vaultAccounting()).currentProfits).to.equal(lockedProfits.sub(loss));
      });

      it("Repay assets with a loss, not coverable with locked fees", async function () {
        const unlockTime = await vault.unlockTime();
        const initialVaultBalance = await native.balanceOf(vault.address);
        const initialInvestorBalance = await native.balanceOf(investor2.address);
        const initialTotalAssets = await vault.totalAssets();
        const currentLoans = (await vault.vaultAccounting()).netLoans;
        const currentProfits = (await vault.vaultAccounting()).currentProfits;
        const latestRepay = (await vault.vaultAccounting()).latestRepay;

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        const timestampBefore = BigNumber.from(blockBefore.timestamp);

        const unlockedProfits = timestampBefore.sub(latestRepay).mul(currentProfits).div(unlockTime);
        const lockedProfits = currentProfits.sub(unlockedProfits);
        // Repay current loans but losing more than locked profits
        const debtToRepay = currentLoans.div(2);
        const extraLoss = BigNumber.from(1);
        const loss = lockedProfits.add(extraLoss);

        // Fail without approval

        await expect(
          vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address),
        ).to.be.revertedWith("ERC20: insufficient allowance");

        // Approve vault for repay
        await native.connect(investor2).approve(vault.address, debtToRepay.sub(loss));
        await vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address);

        // Net loans decreased
        expect((await vault.vaultAccounting()).netLoans).to.equal(currentLoans.sub(debtToRepay));
        // Investor2 balance decreased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.sub(debtToRepay.sub(loss)));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(debtToRepay.sub(loss)));
        // Current profits become 0
        expect((await vault.vaultAccounting()).currentProfits).to.equal(0);
        // Vault assets lose the extra loss
        expect(await vault.totalAssets()).to.equal(initialTotalAssets.sub(extraLoss));
      });

      it("Repay full debt (zero fees)", async function () {
        const initialInvestorBalance = await native.balanceOf(investor2.address);
        const initialVaultBalance = await native.balanceOf(vault.address);
        const currentLoans = (await vault.vaultAccounting()).netLoans;
        // Approve vault for repay
        await native.connect(investor2).approve(vault.address, currentLoans);
        await vault.connect(admin).repay(currentLoans, currentLoans, investor2.address);

        // Net loans are zero
        expect((await vault.vaultAccounting()).netLoans).to.equal(0);
        // Investor2 balance decreased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.sub(currentLoans));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(currentLoans));
      });

      it("Unlock all fees and withdraw assets", async function () {
        const unlockTime = await vault.unlockTime();
        const latestRepay = (await vault.vaultAccounting()).latestRepay;
        let nextTimestapm = parseInt(latestRepay.add(unlockTime).toString());
        await network.provider.send("evm_setNextBlockTimestamp", [nextTimestapm]);
        await network.provider.send("evm_mine");

        const totalAssets = await vault.totalAssets();
        // No loans, no boost and no locked fees -> we expect total assets to be equal to balance
        expect(totalAssets).to.equal(await native.balanceOf(vault.address));

        await vault.connect(investor1).withdraw(totalAssets, investor1.address, investor1.address);

        // Investor1 has total assets
        expect(await native.balanceOf(investor1.address)).to.equal(totalAssets);
        // Vault balance is zero
        expect(await native.balanceOf(vault.address)).to.equal(0);
      });

      it("Withdraw with open loans (insufficient balance)", async function (){

      });

      it("Withdraw with open loans (sufficient balance)", async function (){
        
      });

      it("Repay more than netLoans", async function (){
        
      });

      it("Borrow with boosts", async function (){
        
      });
      
      it("Borrow with boosts", async function (){
        
      });
    });
    // Todo: repay with amount higher than netLoans
    // Todo: withdraw when netLoans are not zero
    // Todo: withdra
  });
});
