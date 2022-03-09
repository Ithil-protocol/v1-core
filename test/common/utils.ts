import { Provider } from "@ethersproject/providers";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { Vault } from "../../src/types/Vault";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";

export const fundVault = async (user: string | Signer | Provider, vault: Vault, token: any, liquidity: BigNumber) => {
  const tokenContract = await ethers.getContractAt(ERC20.abi, token.address);
  await tokenContract.connect(user).approve(vault.address, liquidity);
  await vault.connect(user).stake(token.address, liquidity);
};

export const changeSwapRate = async (
  kyber: MockKyberNetworkProxy,
  token0: any,
  token1: any,
  num: number,
  den: number,
) => {
  await kyber.setRate(token0.address, token1.address, { numerator: num, denominator: den });
  await kyber.setRate(token1.address, token0.address, { numerator: den, denominator: num });
};
