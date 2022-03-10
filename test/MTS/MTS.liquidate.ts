import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../common/utils";

export function checkLiquidate(): void {
  it("check computeLiquidationScore & liquidate", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const investor = this.signers.investor;
    const trader = this.signers.trader;
    const liquidator = this.signers.liquidator;
    const marginTokenLiquidity = ethers.utils.parseUnits("2000.0", 18);
    const marginTokenMargin = ethers.utils.parseUnits("100.0", 18);
    const investmentTokenLiquidity = ethers.utils.parseUnits("500.0", 18);
    const leverage = 10;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, 10, 10);
    await this.vault.whitelistToken(investmentToken.address, 10, 10);

    await marginToken.mintTo(investor.address, marginTokenLiquidity);
    await investmentToken.mintTo(investor.address, investmentTokenLiquidity);
    await marginToken.mintTo(trader.address, marginTokenLiquidity);

    await this.marginTradingStrategy.setRiskFactor(marginToken.address, 5000);
    await this.marginTradingStrategy.setRiskFactor(investmentToken.address, 5000);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await fundVault(investor, this.vault, investmentToken, investmentTokenLiquidity);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

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

    // step 1. open position
    await changeRate(this.mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    await this.marginTradingStrategy.connect(trader).openPosition(order);

    let position0 = await this.marginTradingStrategy.positions(1);
    let liquidationScore0 = await this.marginTradingStrategy.connect(liquidator).computeLiquidationScore(position0);

    // step 2. try to liquidate
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 98 * 10 ** 9);
    let liquidationScore1 = await this.marginTradingStrategy
      .connect(liquidator)
      .computeLiquidationScore(await this.marginTradingStrategy.positions(1));
    await this.liquidatorContract.connect(liquidator).liquidateSingle(this.marginTradingStrategy.address, 1);
    let position1 = await this.marginTradingStrategy.positions(1);
    expect(position1.principal).to.equal(position0.principal);

    // step 3. liquidate
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 95 * 10 ** 9);
    let liquidationScore2 = await this.marginTradingStrategy
      .connect(liquidator)
      .computeLiquidationScore(await this.marginTradingStrategy.positions(1));
    await this.liquidatorContract.connect(liquidator).liquidateSingle(this.marginTradingStrategy.address, 1);

    let position2 = await this.marginTradingStrategy.positions(1);
    expect(position2.principal).to.equal(0);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    expect(liquidationScore1.score).to.lt(BigNumber.from(0));
    expect(liquidationScore2.score).to.gt(BigNumber.from(0));

    expect(initialState.trader_margin).to.gt(finalState.trader_margin);
    expect(initialState.vault_margin).to.lt(finalState.vault_margin);
    expect(initialState.vault_inv).to.lte(finalState.vault_inv);
  });
}
