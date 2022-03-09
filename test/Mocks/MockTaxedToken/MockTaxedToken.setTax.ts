import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkSetTax(): void {
  it("MockTaxedToken: setTax", async function () {
    await this.mockTaxedToken.setTax(1000);
  });
}
