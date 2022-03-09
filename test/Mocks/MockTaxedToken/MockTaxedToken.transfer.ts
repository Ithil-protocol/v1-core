import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkTransfer(): void {
  it("MockTaxedToken: transfer", async function () {
    const amount = ethers.utils.parseUnits("100.0", 5);
    await this.mockTaxedToken.mintTo(this.signers.investor.address, amount);
    await this.mockTaxedToken.connect(this.signers.investor).transfer(this.signers.trader.address, amount);
  });
}
