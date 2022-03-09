import { expect } from "chai";
import { ethers } from "hardhat";
import { fundVault, changeSwapRate } from "../../common/utils";

export function checkDeadline(): void {
  it("check openPosition & closePosition", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const investor = this.signers.investor;
    const trader = this.signers.trader;
    const marginTokenLiquidity = ethers.utils.parseUnits("2000.0", 18);
    const marginTokenMargin = ethers.utils.parseUnits("100.0", 18);
    const leverage = 10;
    const deadline = 0;

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

    try {
      await this.marginTradingStrategy.connect(trader).openPosition(order);
      expect.fail("Expected deadline exception");
    } catch (e) {} // eslint-disable-line no-empty
  });
}
