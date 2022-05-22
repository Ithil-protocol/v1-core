import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkArbitraryRepay(): void {
  it("TestStrategy: arbitraryRepay", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH;
    const borrower = this.signers.trader;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const collateral = ethers.utils.parseUnits("1.0", 17);
    const riskFactor = ethers.utils.parseUnits("2.0", 2);

    await token.mintTo(borrower.address, amount.mul(2));
    await token.connect(borrower).approve(this.vault.address, amount);
    await token.mintTo(this.vault.address, amount.mul(100));
    await this.vault.whitelistToken(token.address, baseFee, fixedFee);

    const initialState = {
      balance: await token.balanceOf(borrower.address),
    };

    await this.TestStrategy.arbitraryBorrow(token.address, amount, riskFactor, borrower.address);

    const rsp = await this.TestStrategy.arbitraryRepay(
      token.address,
      amount,
      collateral,
      fixedFee,
      riskFactor,
      borrower.address,
    );
    const events = (await rsp.wait()).events;

    const finalState = {
      balance: await token.balanceOf(borrower.address),
    };
  });
}
