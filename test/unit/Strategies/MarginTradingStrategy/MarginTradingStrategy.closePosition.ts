import { expect } from "chai";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../../../common/utils";
import {
  marginTokenLiquidity,
  marginTokenMargin,
  leverage,
  baseFee,
  fixedFee,
  minimumMargin,
} from "../../../common/params";

export function checkClosePosition(): void {
  it("MarginTradingStrategy: closePosition", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const { investor, trader } = this.signers;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMargin);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMargin);

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

    const riskFactor1 = await this.marginTradingStrategy.riskFactors(investmentToken.address);
    await changeRate(this.mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(this.mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);

    const [minObtained] = await this.marginTradingStrategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    const order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: minObtained,
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    await this.marginTradingStrategy.connect(trader).openPosition(order);

    const riskFactor2 = await this.marginTradingStrategy.riskFactors(investmentToken.address);

    await changeRate(this.mockKyberNetworkProxy, investmentToken, 11 * 10 ** 10);

    const position = await this.marginTradingStrategy.positions(1);
    const maxSpent = position.allowance;

    await this.marginTradingStrategy.connect(trader).closePosition(1, maxSpent);

    const riskFactor3 = await this.marginTradingStrategy.riskFactors(investmentToken.address);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    expect(initialState.trader_margin).to.lt(finalState.trader_margin);
    expect(initialState.vault_margin).to.lt(finalState.vault_margin);
  });
}
