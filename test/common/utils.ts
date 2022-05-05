import { Provider } from "@ethersproject/providers";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { Vault } from "../../src/types/Vault";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { expect } from "chai";

export const INITIAL_VAULT_STATE = {
  supported: false,
  locked: false,
  wrappedToken: "0x0000000000000000000000000000000000000000",
  creationTime: BigNumber.from(0),
  baseFee: BigNumber.from(0),
  fixedFee: BigNumber.from(0),
  netLoans: BigNumber.from(0),
  insuranceReserveBalance: BigNumber.from(0),
  optimalRatio: BigNumber.from(0),
  treasuryLiquidity: BigNumber.from(0),
};

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

export const compareVaultStates = (state1: any, state2: any) => {
  expect(state1.supported).to.equal(state2.supported);
  expect(state1.locked).to.equal(state2.locked);
  expect(state1.wrappedToken).to.equal(state2.wrappedToken);
  expect(state1.creationTime).to.equal(state2.creationTime);
  expect(state1.baseFee).to.equal(state2.baseFee);
  expect(state1.fixedFee).to.equal(state2.fixedFee);
  expect(state1.netLoans).to.equal(state2.netLoans);
  expect(state1.insuranceReserveBalance).to.equal(state2.insuranceReserveBalance);
  expect(state1.optimalRatio).to.equal(state2.optimalRatio);
  expect(state1.treasuryLiquidity).to.equal(state2.treasuryLiquidity);
};
