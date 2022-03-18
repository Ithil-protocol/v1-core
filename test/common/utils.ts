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

export const changeRate = async (kyber: MockKyberNetworkProxy, token: any, rate: number) => {
  await kyber.setRate(token.address, rate);
};

export const getTokens = async (user: string, token: any, whale: string, amount: number) => {
  const contract = await ethers.getContractAt(ERC20.abi, token);

  await ethers.provider.send("hardhat_impersonateAccount", [whale]);
  const impersonatedAccount = ethers.provider.getSigner(whale);
  await contract.connect(impersonatedAccount).transfer(user, amount);
};
