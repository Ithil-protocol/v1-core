import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export const marginTokenLiquidity: BigNumber = ethers.utils.parseUnits("2000.0", 18);
export const marginTokenLiquidityUSDC: BigNumber = ethers.utils.parseUnits("2000.0", 6);
export const marginTokenMargin: BigNumber = ethers.utils.parseUnits("100.0", 18);
export const marginTokenMarginUSDC: BigNumber = ethers.utils.parseUnits("100.0", 6);
export const investmentTokenLiquidity: BigNumber = ethers.utils.parseUnits("500.0", 18);
export const amount: BigNumber = ethers.utils.parseUnits("100.0", 18);
export const baseFee = 10;
export const fixedFee = 10;
export const minimumMargin: BigNumber = ethers.utils.parseUnits("1.0", 18);
export const minimumMarginUSDC: BigNumber = ethers.utils.parseUnits("1.0", 6);
export const stakingCap: BigNumber = ethers.utils.parseUnits("10000.0", 18);
export const leverage = 10;
export const slippage = 1;
export const tax = 1;
export const yearnPrice = 1;
