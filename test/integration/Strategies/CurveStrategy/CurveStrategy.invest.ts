import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault } from "../../../common/utils";
import {
  marginTokenLiquidityUSDC,
  marginTokenMarginUSDC,
  leverage,
  baseFee,
  fixedFee,
  minimumMargin,
  minimumMarginUSDC,
  stakingCap,
} from "../../../common/params";

export function checkPerformInvestment(): void {
  it("CurveStrategy: trade", async function () {
    const { investor, trader } = this.signers;
    const marginToken = this.usdc;
    const investmentToken = this.usdc;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMarginUSDC, stakingCap);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidityUSDC);
    await marginToken.connect(trader).approve(this.curveStrategy.address, marginTokenMarginUSDC);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    const order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMarginUSDC,
      collateralIsSpentToken: true,
      minObtained: marginTokenMarginUSDC,
      maxSpent: marginTokenMarginUSDC.mul(leverage),
      deadline: deadline,
    };

    await this.curveStrategy.connect(trader).openPosition(order);

    const position = await this.curveStrategy.positions(1);
    const maxSpent = position.allowance;

    await this.curveStrategy.connect(trader).closePosition(1, maxSpent);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    expect(initialState.trader_margin).to.gt(finalState.trader_margin);
    expect(initialState.vault_margin).to.lt(finalState.vault_margin);
  });
}
