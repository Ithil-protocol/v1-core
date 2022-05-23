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
} from "../../../common/params";

export function checkPerformInvestment(): void {
  it("MarginTradingStrategy: trade", async function () {
    const marginToken = this.dai;
    const investmentToken = this.weth;
    const { investor, trader } = this.signers;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMargin);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMargin);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader).approve(this.marginTradingStrategy.address, marginTokenMargin);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    const [price] = await this.marginTradingStrategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    const order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: price.mul(99).div(100), // 1% slippage
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    await this.marginTradingStrategy.connect(trader).openPosition(order);

    const position = await this.marginTradingStrategy.positions(1);
    const maxSpent = position.allowance;

    await this.marginTradingStrategy.connect(trader).closePosition(1, maxSpent);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };
  });
}
