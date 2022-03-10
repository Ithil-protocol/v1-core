import { expect } from "chai";
import { ethers } from "hardhat";
import { fundVault, changeRate } from "../common/utils";

export function checkPosition(): void {
  it("check openPosition & closePosition", async function () {
    const marginToken = this.mockTaxedToken;
    const investmentToken = this.mockWETH;
    const investor = this.signers.investor;
    const trader = this.signers.trader;
    const marginTokenLiquidity = ethers.utils.parseUnits("2000.0", 18);
    const marginTokenMargin = ethers.utils.parseUnits("100.0", 18);
    const leverage = 10;
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

    await this.vault.whitelistToken(marginToken.address, 10, 10);
    await this.vault.whitelistToken(investmentToken.address, 10, 10);
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

    await this.yearnStrategy.connect(trader).openPosition(order);

    await this.yearnStrategy.connect(trader).closePosition(1);

    const finalState = {
      trader_margin: await marginToken.balanceOf(trader.address),
      trader_inv: await investmentToken.balanceOf(trader.address),
      vault_margin: await marginToken.balanceOf(this.vault.address),
      vault_inv: await investmentToken.balanceOf(this.vault.address),
    };

    expect(initialState.trader_margin).to.lt(finalState.trader_margin);
    expect(initialState.vault_margin).to.lt(finalState.vault_margin);
  });

  // TODO: editPosition is not implemented yet
  // it("check editPosition", async function () {
  // });
}
