import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { token0, token1 } from "../../constants";

export function checkRate(): void {
  it("MockKyberNetworkProxy: setRate", async function () {
    await this.mockKyberNetworkProxy.setRate(token0, token1, { numerator: 10, denominator: 11 });
  });
  it("MockKyberNetworkProxy: getExpectedRate", async function () {
    await this.mockKyberNetworkProxy.setRate(token0, token1, { numerator: 10, denominator: 11 });
    const expectedRate = await this.mockKyberNetworkProxy.getExpectedRate(token0, token1, 100);
    console.log({ expectedRate });
  });
}
