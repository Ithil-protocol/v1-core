import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkMint(): void {
  it("MockToken: mint", async function () {
    await this.mockToken.mint();
  });
}
