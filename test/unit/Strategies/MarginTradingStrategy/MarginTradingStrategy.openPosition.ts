import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../../../common/utils";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";

export function checkOpenPosition(): void {
  it("MarginTradingStrategy: openPosition", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const { investor, trader } = this.signers;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, 10, 10);
    await this.vault.whitelistToken(investmentToken.address, 10, 10);
    await marginToken.mintTo(investor.address, marginTokenLiquidity);
    await marginToken.mintTo(trader.address, marginTokenLiquidity);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader).approve(this.marginTradingStrategy.address, marginTokenMargin);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    const order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: marginTokenMargin,
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    const initialRiskFactor = await this.marginTradingStrategy.riskFactors(investmentToken.address);
    console.log("Initial risk factor " + ethers.utils.formatUnits(initialRiskFactor, 2) + "%");

    await changeRate(this.mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    await this.marginTradingStrategy.connect(trader).openPosition(order);

    const finalRiskFactor = await this.marginTradingStrategy.riskFactors(investmentToken.address);
    console.log("Final risk factor " + ethers.utils.formatUnits(finalRiskFactor, 2) + "%");
    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };
  });
}
