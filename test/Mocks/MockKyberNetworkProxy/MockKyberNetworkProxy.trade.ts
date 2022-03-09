import { expect } from "chai";
import { BigNumber } from "ethers";
import { artifacts, ethers, waffle } from "hardhat";
import { Artifact } from "hardhat/types";
import { MockToken } from "../../../src/types/MockToken";
import { token0, token1 } from "../../constants";

export function checkTrade(): void {
  it("MockKyberNetworkProxy: trade", async function () {
    const mockToken0 = this.mockTaxedToken;
    const mockToken1 = this.mockWETH;
    const maxAmount = ethers.utils.parseUnits("100.0", 5);

    await mockToken0.mintTo(this.signers.liquidator.address, maxAmount);
    await mockToken0.connect(this.signers.liquidator.address).approve(this.signers.investor.address, maxAmount);
    await mockToken1.mintTo(this.signers.investor.address, maxAmount);
    await mockToken1.connect(this.signers.investor.address).approve(this.signers.liquidator.address, maxAmount);

    const tx = await this.mockKyberNetworkProxy.connect(this.signers.investor).trade(
      mockToken0.address,
      100,
      mockToken1.address,
      this.signers.trader.address,
      0, // unncessary
      0,
      this.signers.trader.address, // unncessary
    );

    // console.log(tx);
  });
}
