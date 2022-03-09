import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkTransferFrom(): void {
  it("MockTaxedToken: transferFrom", async function () {
    await this.mockTaxedToken.setTax(1);
    await this.mockTaxedToken.mintTo(this.signers.investor.address, amount);
    await this.mockTaxedToken.connect(this.signers.investor).approve(this.signers.trader.address, amount.div(2));
    console.log(await this.mockTaxedToken.allowance(this.signers.investor.address, this.signers.trader.address));
    await this.mockTaxedToken.transferFrom(this.signers.investor.address, this.signers.trader.address, amount.div(2));
  });
}
