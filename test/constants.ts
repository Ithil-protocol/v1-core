const { ethers } = require("hardhat");

export const marginTokenLiquidity = ethers.utils.parseUnits("2000.0", 18);
export const marginTokenMargin = ethers.utils.parseUnits("100.0", 18);
export const investmentTokenLiquidity = ethers.utils.parseUnits("500.0", 18);
export const leverage = 10;
export const slippage = 1;
export const tax = 1;
export const yearnPrice = 1;
