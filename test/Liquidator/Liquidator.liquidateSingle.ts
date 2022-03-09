import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault, changeSwapRate } from "../utils";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../constants";

export function checkLiquidateSingle(): void {
  it("Liquidator: liquidateSingle", async function () {
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

    const order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: marginTokenMargin,
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    await changeSwapRate(this.mockKyberNetworkProxy, marginToken, investmentToken, 1, 10);
    await this.marginTradingStrategy.connect(trader).openPosition(order);

    this.liquidator.liquidateSingle(this.marginTradingStrategy.address, 1);
  });
}
