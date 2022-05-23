import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../../../common/utils";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";

export function checkOpenPosition(): void {
  it("LidoStrategy: openPosition", async function () {
    const { investor, trader } = this.signers;
    const marginToken = this.weth;
    const investmentToken = this.dai;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, 10, 10);
    await this.vault.whitelistToken(investmentToken.address, 10, 10);

    await fundVault(investor, this.vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader).approve(this.LidoStrategy.address, marginTokenMargin);

    const initialState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
      strategy_bal: await investmentToken.balanceOf(this.LidoStrategy.address),
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

    const quoted = await this.LidoStrategy.connect(trader).quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage + 1),
    );

    await this.LidoStrategy.connect(trader).openPosition(order);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
      strategy_bal: await investmentToken.balanceOf(this.LidoStrategy.address),
    };

    //expect(initialState.trader_margin).to.lt(finalState.trader_margin);
    //expect(initialState.vault_margin).to.lt(finalState.vault_margin);
  });
}
