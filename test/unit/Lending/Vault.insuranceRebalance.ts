import { expect } from "chai";
import { ethers } from "hardhat";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { expandTo18Decimals } from "../../common/utils";

export function checkRebalanceInsurance(): void {
  it("Vault: rebalance insurance", async function () {
    const token = this.mockWETH;
    const treasury = this.signers.admin;

    // Get wrapped token contract
    const wrappedTokenAddress = (await this.vault.vaults(token.address)).wrappedToken;
    const wrappedToken = await ethers.getContractAt(ERC20.abi, wrappedTokenAddress);

    // Amount to stake
    const amountToPutAsInsurance = expandTo18Decimals(1000);
    // Initial staker's liquidity
    const initialTreasuryLiquidity = expandTo18Decimals(10000);

    // give tokens to the treasury and approve the vault
    await token.mintTo(treasury.address, initialTreasuryLiquidity);
    await token.connect(treasury).approve(this.vault.address, initialTreasuryLiquidity);

    // Treasury adds insurance reserve
    await this.vault.connect(treasury).addInsurance(token.address, amountToPutAsInsurance);

    const middleState = {
      balance: await token.balanceOf(treasury.address),
      wrappedBalance: await wrappedToken.balanceOf(treasury.address),
      insuranceReserveBalance: (await this.vault.vaults(token.address)).insuranceReserveBalance,
    };

    expect(middleState.wrappedBalance).to.equal(0);
    expect(middleState.insuranceReserveBalance).to.equal(amountToPutAsInsurance);

    // Transfer tokens to vault: it has the same effect of fee generation
    const amountAdded = expandTo18Decimals(100);
    await token.mintTo(this.vault.address, amountAdded);

    // Rebalancing the insurance reserve: anybody can do it (not only treasury)
    await this.vault.connect(this.signers.investor).rebalanceInsurance(token.address);
  });
}
