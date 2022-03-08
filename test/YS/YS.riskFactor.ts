import { expect } from "chai";
import { BigNumber } from "ethers";

export function checkRiskFactor(): void {
  it("check setRiskFactor", async function () {
    const riskFactor = 200;
    const token = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    const initialState = {
      riskFactor: await this.yearnStrategy.riskFactors(token),
    };

    await this.yearnStrategy.setRiskFactor(token, riskFactor);

    const finalState = {
      riskFactor: await this.yearnStrategy.riskFactors(token),
    };

    expect(finalState.riskFactor).to.equal(BigNumber.from(riskFactor));
  });

  it("check computePairRiskFactor", async function () {
    const riskFactor0 = 200;
    const riskFactor1 = 300;
    const token0 = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    const token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const initialState = {
      pairRiskFactor: await this.yearnStrategy.computePairRiskFactor(token0, token1),
    };

    await this.yearnStrategy.setRiskFactor(token0, riskFactor0);
    await this.yearnStrategy.setRiskFactor(token1, riskFactor1);

    const finalState = {
      pairRiskFactor: await this.yearnStrategy.computePairRiskFactor(token0, token1),
    };

    expect(finalState.pairRiskFactor).to.equal(BigNumber.from(riskFactor0).add(BigNumber.from(riskFactor1)).div(2));
  });
}
