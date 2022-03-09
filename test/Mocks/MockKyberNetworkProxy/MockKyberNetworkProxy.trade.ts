import { expect } from "chai";
import { BigNumber } from "ethers";
import { artifacts, ethers, waffle } from "hardhat";
import { Artifact } from "hardhat/types";
import { MockToken } from "../../../src/types/MockToken";
import { token0, token1 } from "../../constants";

export function checkTrade(): void {
  it("MockKyberNetworkProxy: trade", async function () {
    const mockTokenArtifact: Artifact = await artifacts.readArtifact("MockToken");
    const mockToken0 = <MockToken>(
      await waffle.deployContract(this.signers.admin, mockTokenArtifact, [
        "Token0",
        "TKN0",
        this.mockKyberNetworkProxy.address,
      ])
    );
    const mockToken1 = <MockToken>(
      await waffle.deployContract(this.signers.admin, mockTokenArtifact, [
        "Token1",
        "TKN1",
        this.mockKyberNetworkProxy.address,
      ])
    );
    const maxAmount = ethers.utils.parseUnits("100.0", 5);

    await mockToken0.mintTo(this.signers.investor.address, maxAmount);
    await mockToken0.connect(this.signers.investor).approve(this.mockKyberNetworkProxy.address, maxAmount);
    await mockToken1.mintTo(this.signers.trader.address, maxAmount);
    await mockToken1.connect(this.signers.trader).approve(this.signers.investor.address, maxAmount);

    const tx = await this.mockKyberNetworkProxy.connect(this.signers.investor).trade(
      mockToken0.address,
      100,
      mockToken1.address,
      this.signers.trader.address,
      0, // unncessary
      0,
      this.signers.trader.address, // unncessary
    );

    console.log(tx);
  });
}
