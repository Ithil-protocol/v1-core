import { network, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { TokenizedVault } from "../../src/types/TokenizedVault";
import type { MockTimeTokenizedVault } from "../../src/types/MockTimeTokenizedVault";
import type { MockToken } from "../../src/types/MockToken";
import { tokenizedVaultFixture, mockTimeTokenizedVaultFixture } from "../common/mockfixtures";
import exp from "constants";
import { FunctionFragment } from "@ethersproject/abi";

describe("Tokenized Vault tests: basis", function () {
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

    describe("Borrow and repay", function () {
      let initialShares: BigNumber;
      let initialAssets: BigNumber;
      before("Start with a filled vault", async () => {
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
        const vaultAccounting = await vault.vaultAccounting();
        const currentLoans = vaultAccounting.netLoans;
        let blockNumBefore = await ethers.provider.getBlockNumber();
        let blockBefore = await ethers.provider.getBlock(blockNumBefore);
        let timestampBefore = BigNumber.from(blockBefore.timestamp);

        const initialLockedProfits = vaultAccounting.currentProfits
          .mul(unlockTime.sub(timestampBefore.sub(vaultAccounting.latestRepay)))
          .div(unlockTime);
        // Repay current loans but losing more than locked profits
        const debtToRepay = currentLoans.div(2);
        const extraLoss = BigNumber.from(42);
        const loss = initialLockedProfits.add(extraLoss);

        // Fail without approval

        await expect(
          vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address),
        ).to.be.revertedWith("ERC20: insufficient allowance");

        const predictedProfits = initialLockedProfits.sub(loss);
        // Approve vault for repay
        await native.connect(investor2).approve(vault.address, debtToRepay.sub(loss));
        await vault.connect(admin).repay(debtToRepay.sub(loss), debtToRepay, investor2.address);

        // Net loans decreased
        expect((await vault.vaultAccounting()).netLoans).to.equal(currentLoans.sub(debtToRepay));
        // Investor2 balance decreased
        expect(await native.balanceOf(investor2.address)).to.equal(initialInvestorBalance.sub(debtToRepay.sub(loss)));
        // Vault balance increased
        expect(await native.balanceOf(vault.address)).to.equal(initialVaultBalance.add(debtToRepay.sub(loss)));
        // Current profits are less than the previous locked profits and now negative
        // Precise calculation cannot be done because timestamp is not controllable in TS (use mockTime to do precise tests)
        // But since we calculated initialLockedProfits time increased -> less locked profits
        expect((await vault.vaultAccounting()).currentProfits).to.be.lte(predictedProfits);
        // Todo: check with mock time that assets stay constant (here they change very slightly)
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
        // Total assets are zero
        expect(await vault.totalAssets()).to.equal(0);
      });

      it("Withdraw with open loans (insufficient balance)", async function () {
        // Refill investor
        await native.connect(investor1).mint();

        const initialInvestorBalance = await native.balanceOf(investor1.address);
        // Approve and deposit
        await native.connect(investor1).approve(vault.address, initialInvestorBalance);
        await vault.connect(investor1).deposit(initialInvestorBalance, investor1.address);

        // Open a loan
        const toBorrow = initialInvestorBalance.div(2);
        await vault.connect(admin).borrow(toBorrow, admin.address);

        const maximumWithdraw = await vault.maxWithdraw(investor1.address);
        // Maximum withdraw should be the current vault balance
        expect(maximumWithdraw).to.equal(await native.balanceOf(vault.address));
        // Withdrawing now should fail
        await expect(
          vault.connect(investor1).withdraw(initialInvestorBalance, investor1.address, investor1.address),
        ).to.be.revertedWith(
          "ERROR_Vault__Insufficient_Liquidity(" + ethers.utils.formatUnits(maximumWithdraw, 0) + ")",
        );
      });

      it("Withdraw with open loans (sufficient balance)", async function () {
        // Withdraw maximum available
        const initialAssets = await vault.totalAssets();
        const maximumWithdraw = await vault.connect(investor1).maxWithdraw(investor1.address);
        const initialInvestorBalance = await native.balanceOf(investor1.address);
        await vault.connect(investor1).withdraw(maximumWithdraw, investor1.address, investor1.address);

        // Investor balance increased
        expect(await native.balanceOf(investor1.address)).to.equal(initialInvestorBalance.add(maximumWithdraw));
        // Maximum withdraw is now zero
        expect(await vault.maxWithdraw(investor1.address)).to.equal(0);
        // Assets decreased
        const assets = await vault.totalAssets();
        // Assets are equal to both initialAssets - maximumWithdraw and totalLoans
        expect(assets).to.equal(initialAssets.sub(maximumWithdraw));
        expect(assets).to.equal((await vault.vaultAccounting()).netLoans);
        // Investors shares are still worth total assets
        expect(await vault.convertToAssets(await vault.balanceOf(investor1.address))).to.equal(assets);
      });

      it("Repay more than netLoans", async function () {
        // Refill admin
        await native.connect(admin).mint();
        const netLoans = (await vault.vaultAccounting()).netLoans;
        const amountToRepay = netLoans.add(1);

        // Repay one more than netLoans
        await native.connect(admin).approve(vault.address, amountToRepay);
        await vault.connect(admin).repay(netLoans, amountToRepay, admin.address);

        // Net loans are now zero
        expect((await vault.vaultAccounting()).netLoans).to.equal(0);
      });
    });
  });
});
describe("Tokenized Vault tests: mock time for fees testing", function () {
  const createFixtureLoader = waffle.createFixtureLoader;

  type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

  let wallet: Wallet, other: Wallet;

  let native: MockToken;
  let admin: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;
  let createVault: ThenArg<ReturnType<typeof mockTimeTokenizedVaultFixture>>["createVault"];
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  let vault: MockTimeTokenizedVault;

  before("load fixture", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
    ({ native, admin, investor1, investor2, createVault } = await loadFixture(mockTimeTokenizedVaultFixture));
    vault = await createVault();
  });

  describe("Deployment", function () {
    describe("Validations", function () {
      const initialTime = BigNumber.from(1601906400);
      it("Vault time should be 1601906400", async function () {
        expect(await vault.time()).to.equal(initialTime);
      });

      it("Properly advance time", async function () {
        await vault.advanceTime(10);
        expect(await vault.time()).to.equal(initialTime.add(10));
      });
    });
  });

  describe("Fees unlock", function () {
    it("Generate fees with zero loans", async function () {
      // Refill investor and deposit
      await native.connect(investor1).mint();
      const initialInvestorBalance = await native.balanceOf(investor1.address);
      await native.connect(investor1).approve(vault.address, initialInvestorBalance);
      await vault.connect(investor1).deposit(initialInvestorBalance, investor1.address);

      // Everything is free liquidity
      const initialFreeLiquidity = await vault.freeLiquidity();
      expect(initialFreeLiquidity).to.equal(initialInvestorBalance);

      // Refill admin for fees generation
      await native.connect(admin).mint();

      const initialAdminBalance = await native.balanceOf(admin.address);
      const initialVaultAssets = await vault.totalAssets();
      const toRepay = initialAdminBalance.div(2);
      // Repay even for zero loans should not be a problem
      await native.connect(admin).approve(vault.address, toRepay);
      await vault.connect(admin).repay(toRepay, 0, admin.address);
      // Assets stay constant (fees still locked)
      expect(await vault.totalAssets()).to.equal(initialVaultAssets);
      // Free liquidity is constant
      expect(await vault.freeLiquidity()).to.equal(initialFreeLiquidity);
      // Check there is no dust
      const vaultAccounting = await vault.vaultAccounting();
      expect(vaultAccounting.netLoans).to.equal(0);
      // Current profits increased
      expect(vaultAccounting.currentProfits).to.equal(toRepay);
      // Latest repay is time
      expect(vaultAccounting.latestRepay).to.equal(await vault.time());
    });

    it("Unlock one-third of the fees", async function () {
      const unlockTime = await vault.unlockTime();
      const initialAssets = await vault.totalAssets();
      const vaultAccounting = await vault.vaultAccounting();
      // Check assets
      expect(initialAssets).to.equal(
        (await native.balanceOf(vault.address)).add(vaultAccounting.netLoans).sub(vaultAccounting.currentProfits),
      );
      const initialFreeLiquidity = await vault.freeLiquidity();
      await vault.advanceTime(unlockTime.div(3));

      const lockedProfits = vaultAccounting.currentProfits
        .mul(unlockTime.sub((await vault.time()).sub(vaultAccounting.latestRepay)))
        .div(unlockTime);

      // Assets increased
      expect(await vault.totalAssets()).to.equal(initialAssets.add(vaultAccounting.currentProfits).sub(lockedProfits));
      // Free liquidity increased
      expect(await vault.freeLiquidity()).to.equal(
        initialFreeLiquidity.add(vaultAccounting.currentProfits).sub(lockedProfits),
      );
    });

    it("Cannot withdraw more than free liquidity", async function () {
      const currentBalance = await native.balanceOf(vault.address);
      const freeLiquidity = await vault.freeLiquidity();
      await expect(vault.withdraw(currentBalance, investor1.address, investor1.address)).to.be.revertedWith(
        "ERROR_Vault__Insufficient_Liquidity(" + ethers.utils.formatUnits(freeLiquidity, 0) + ")",
      );
    });

    it("Cannot borrow more than free liquidity", async function () {
      const currentBalance = await native.balanceOf(vault.address);
      const freeLiquidity = await vault.freeLiquidity();
      await expect(vault.connect(admin).borrow(currentBalance, admin.address)).to.be.revertedWith(
        "ERROR_Vault__Insufficient_Free_Liquidity(" + ethers.utils.formatUnits(freeLiquidity, 0) + ")",
      );
    });

    it("Unlock remaining part of fees and withdraw", async function () {
      const unlockTime = await vault.unlockTime();
      const vaultAccounting = await vault.vaultAccounting();
      await vault.advanceTime(vaultAccounting.latestRepay.add(unlockTime).sub(await vault.time()));

      const currentLiquidity = await native.balanceOf(vault.address);
      // All profits are now unlocked
      expect(await vault.totalAssets()).to.equal(currentLiquidity);
      // All liquidity is free
      expect(await vault.freeLiquidity()).to.equal(currentLiquidity);
      // Withdraw
      await vault.connect(investor1).withdraw(currentLiquidity, investor1.address, investor1.address);
      expect(await native.balanceOf(investor1.address)).to.equal(currentLiquidity);
      expect(await vault.totalAssets()).to.equal(0);
    });
  });

  describe("Direct minting and burning", function () {
    let amountToDeposit;
    before("Refill investors and deposit", async () => {
      await native.connect(investor1).mint();
      amountToDeposit = await native.balanceOf(investor1.address);
      await native.connect(investor1).approve(vault.address, amountToDeposit);
      await vault.connect(investor1).deposit(amountToDeposit, investor1.address);
      const amountToMint = amountToDeposit.sub(await native.balanceOf(investor2.address));
      await native.connect(admin).mintTo(investor2.address, amountToMint);
      await native.connect(investor2).approve(vault.address, amountToDeposit);
      await vault.connect(investor2).deposit(amountToDeposit, investor2.address);

      expect(await vault.maxWithdraw(investor1.address)).to.equal(await vault.maxWithdraw(investor2.address));
    });

    it("Direct mint dilutes the other investor", async function () {
      const investorShares = await vault.balanceOf(investor2.address);
      const initialMaximumWithdraw1 = await vault.maxWithdraw(investor1.address);
      const initialMaximumWithdraw2 = await vault.maxWithdraw(investor2.address);

      // Check maximum withdraw stay the same while direct minting
      await vault.connect(admin).directMint(investorShares, investor2.address);
      expect(initialMaximumWithdraw1).to.equal(await vault.maxWithdraw(investor1.address));

      // Advance time to unlock the loss
      await vault.advanceTime(await vault.unlockTime());
      const finalMaximumWithdraw1 = await vault.maxWithdraw(investor1.address);
      const finalMaximumWithdraw2 = await vault.maxWithdraw(investor2.address);

      // Initially with the same shares, now investor2 has twice as many as investor1
      // Therefore investor1 can withdraw only one-third of the total amount

      expect(finalMaximumWithdraw1).to.equal(initialMaximumWithdraw1.mul(2).div(3));
      expect(finalMaximumWithdraw2).to.equal(initialMaximumWithdraw2.mul(4).div(3));

      // The total amount is very close to be constant, but there are rounding errors (not avoidable)
    });

    it("Direct burn boosts the other investor", async function () {
      const investorShares = await vault.balanceOf(investor2.address);
      const initialMaximumWithdraw1 = await vault.maxWithdraw(investor1.address);
      const initialMaximumWithdraw2 = await vault.maxWithdraw(investor2.address);
      // Burn three-quarters of the shares (approve first!!)
      await vault.connect(investor2).approve(admin.address, investorShares.mul(3).div(4));

      // Check maximum withdraw stay the same while direct burning
      await vault.connect(admin).directBurn(investorShares.mul(3).div(4), investor2.address);
      expect(initialMaximumWithdraw1).to.equal(await vault.maxWithdraw(investor1.address));

      expect(await vault.balanceOf(investor1.address)).to.equal((await vault.balanceOf(investor2.address)).mul(2));

      // Unlock fees
      await vault.advanceTime(await vault.unlockTime());
      const finalMaximumWithdraw1 = await vault.maxWithdraw(investor1.address);
      const finalMaximumWithdraw2 = await vault.maxWithdraw(investor2.address);

      // Initially shares2 = 2 * shares1, now shares1 = 2 * shares2
      // So shares1 passed from 1/3 to 2/3 -> doubled, similarly shares2 halved (-1 for rounding errors)

      expect(finalMaximumWithdraw1.sub(1)).to.equal(initialMaximumWithdraw1.mul(2));
      expect(finalMaximumWithdraw2).to.equal(initialMaximumWithdraw2.div(2));

      // The total amount is very close to be constant, but there are rounding errors (not avoidable)
    });

    it("Burning all supply should fail", async function () {
      // Burn everything
      const investor1Shares = await vault.balanceOf(investor1.address);
      const investor2Shares = await vault.balanceOf(investor2.address);
      await vault.connect(investor1).approve(admin.address, investor1Shares);
      await vault.connect(investor2).approve(admin.address, investor2Shares);
      await vault.connect(admin).directBurn(investor1Shares, investor1.address);

      await expect(vault.connect(admin).directBurn(investor2Shares, investor2.address)).to.be.revertedWith(
        "ERROR_Vault__Supply_Burned()",
      );
    });

    it("Assets can be withdrawn after burning", async function () {
      // At this point, investor2 has all shares
    });
  });
});
