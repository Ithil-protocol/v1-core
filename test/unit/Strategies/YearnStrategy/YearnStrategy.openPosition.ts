import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault } from "../../../common/utils";
import {
  marginTokenLiquidity,
  marginTokenMargin,
  leverage,
  baseFee,
  fixedFee,
  minimumMargin,
  stakingCap,
} from "../../../common/params";

export function checkOpenPosition(): void {
  it("YearnStrategy: openPosition", async function () {
    const { investor, trader } = this.signers;
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    const borrowed = marginTokenMargin.div(2);
    const collateralReceived = marginTokenMargin.div(2);

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMargin, stakingCap);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMargin, stakingCap);

    await marginToken.mintTo(investor.address, marginTokenLiquidity);
    await marginToken.mintTo(trader.address, marginTokenLiquidity);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader).approve(this.yearnStrategy.address, marginTokenMargin);

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

    await this.mockYearnRegistry.setSharePrice(1);
    await this.yearnStrategy.connect(trader).openPosition(order);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    expect(initialState.trader_margin).to.gt(finalState.trader_margin);
    expect(initialState.vault_margin).to.gt(finalState.vault_margin);
  });
}
