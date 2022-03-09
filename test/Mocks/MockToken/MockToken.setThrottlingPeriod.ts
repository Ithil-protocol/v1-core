import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkSetThrottlingPeriod(): void {
  it("MockToken: setThrottlingPeriod", async function () {
    await this.mockToken.setThrottlingPeriod(100);
  });
}
