import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkTransfer(): void {
  it("MockTaxedToken: transfer", async function () {
    await this.mockTaxedToken.mintTo(this.signers.investor.address, amount);
    await this.mockTaxedToken.connect(this.signers.investor).transfer(this.signers.trader.address, amount);
  });
}
