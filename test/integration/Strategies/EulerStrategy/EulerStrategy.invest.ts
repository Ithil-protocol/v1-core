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
import { etoken } from "./constants";

export function checkPerformInvestment(): void {
  it("EulerStrategy: trade", async function () {
    const { investor, trader } = this.signers;
    const marginToken = this.dai;
    const investmentToken = this.weth;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, baseFee, fixedFee, minimumMargin);
    await this.vault.whitelistToken(investmentToken.address, baseFee, fixedFee, minimumMargin);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader).approve(this.eulerStrategy.address, marginTokenMargin);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    const order = {
      spentToken: marginToken.address,
      obtainedToken: etoken,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: marginTokenMargin,
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    await this.eulerStrategy.connect(trader).openPosition(order);

    const position = await this.eulerStrategy.positions(1);
    const maxSpent = position.allowance;

    await this.eulerStrategy
      .connect(trader)
      .closePosition(1, maxSpent, { gasPrice: ethers.utils.parseUnits("500", "gwei"), gasLimit: 30000000 });

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
