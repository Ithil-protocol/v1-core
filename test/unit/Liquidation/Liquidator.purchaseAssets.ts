import { fundVault, changeRate } from "../../common/utils";
import {
  marginTokenLiquidity,
  marginTokenMargin,
  leverage,
  baseFee,
  fixedFee,
  minimumMargin,
  stakingCap,
} from "../../common/params";

export function checkPurchaseAssets(): void {
  it("Liquidator: purchaseAssets", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const { investor, trader } = this.signers;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMargin, stakingCap);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMargin, stakingCap);

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

    await changeRate(this.mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    await this.marginTradingStrategy.connect(trader).openPosition(order);

    await changeRate(this.mockKyberNetworkProxy, investmentToken, 11 * 10 ** 10);

    await this.liquidator.purchaseAssets(this.marginTradingStrategy.address, 1, 10);
  });
}
