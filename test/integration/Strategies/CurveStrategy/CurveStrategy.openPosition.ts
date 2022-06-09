import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../../../common/utils";
import {
  marginTokenLiquidityUSDC,
  marginTokenMarginUSDC,
  leverage,
  baseFee,
  fixedFee,
  minimumMarginUSDC,
  stakingCap,
} from "../../../common/params";

export function checkOpenPosition(): void {
  it("CurveStrategy: openPosition", async function () {
    const { investor, trader } = this.signers;
    const marginToken = this.usdc;
    const investmentToken = this.dai;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMarginUSDC, stakingCap);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMarginUSDC, stakingCap);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidityUSDC);
    await marginToken.connect(trader).approve(this.CurveStrategy.address, marginTokenMarginUSDC);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
      strategy_bal: await investmentToken.balanceOf(this.CurveStrategy.address),
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

    const quoted = await this.CurveStrategy.connect(trader).quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMarginUSDC.mul(leverage + 1),
    );

    await this.CurveStrategy.connect(trader).openPosition(order);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
      strategy_bal: await investmentToken.balanceOf(this.CurveStrategy.address),
    };

    //expect(initialState.trader_margin).to.lt(finalState.trader_margin);
    //expect(initialState.vault_margin).to.lt(finalState.vault_margin);
  });
}
