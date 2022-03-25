import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkName(): void {
  it("YearnStrategy: name", async function () {
    const name = await this.yearnStrategy.name();
  });
}
