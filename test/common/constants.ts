import { BigNumber } from "ethers";

const { ethers } = require("hardhat");

export const marginTokenLiquidity = ethers.utils.parseUnits("2000.0", 18);
export const marginTokenMargin = ethers.utils.parseUnits("100.0", 18);
export const investmentTokenLiquidity = ethers.utils.parseUnits("500.0", 18);
export const amount: BigNumber = ethers.utils.parseUnits("100.0", 18);
export const leverage = 10;
export const slippage = 1;
export const tax = 1;
export const yearnPrice = 1;

export const token0 = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
export const token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
