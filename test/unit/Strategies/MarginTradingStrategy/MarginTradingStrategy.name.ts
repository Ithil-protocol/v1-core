import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkName(): void {
  it("MarginTradingStrategy: name", async function () {
    const name = await this.marginTradingStrategy.name();
  });
}
