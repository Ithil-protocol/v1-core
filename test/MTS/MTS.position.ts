import { Provider } from "@ethersproject/providers";
import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
const ERC20 = require("@openzeppelin/contracts/build/contracts/ERC20.json");
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockTaxedToken } from "../../src/types/MockTaxedToken";
import { MockWETH } from "../../src/types/MockWETH";
import { Vault } from "../../src/types/Vault";

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
    await marginToken.connect(trader).approve(this.marginTradingStrategy.address, marginTokenMargin);

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

    await changeSwapRate(this.mockKyberNetworkProxy, marginToken, investmentToken, 1, 10);
    await this.marginTradingStrategy.connect(trader).openPosition(order);

    await changeSwapRate(this.mockKyberNetworkProxy, marginToken, investmentToken, 1, 11);
    await this.marginTradingStrategy.connect(trader).closePosition(1);

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

const fundVault = async (user: string | Signer | Provider, vault: Vault, token: any, liquidity: BigNumber) => {
  const tokenContract = await ethers.getContractAt(ERC20.abi, token.address);
  await tokenContract.connect(user).approve(vault.address, liquidity);
  await vault.connect(user).stake(token.address, liquidity);
};

const changeSwapRate = async (kyber: MockKyberNetworkProxy, token0: any, token1: any, num: number, den: number) => {
  await kyber.setRate(token0.address, token1.address, { numerator: num, denominator: den });
  await kyber.setRate(token1.address, token0.address, { numerator: den, denominator: num });
};
