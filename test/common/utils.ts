import { Provider } from "@ethersproject/providers";
import { BigNumber, ContractTransaction, Signer } from "ethers";
import { ethers } from "hardhat";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../src/types/MockWETH";
import { Vault } from "../../src/types/Vault";
import { MockTokenisedVault } from "../../src/types/MockTokenisedVault";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { expect } from "chai";
import { BindOptions } from "dgram";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import type { MockToken } from "../../src/types/MockToken";
import { isNativeError } from "util/types";

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

export const mintAndStake = async (
  investor: SignerWithAddress,
  vault: Vault,
  mockToken: MockWETH,
  firstStakerWealth: BigNumber,
  amountToStake: BigNumber,
): Promise<ContractTransaction> => {
  // Fund investor with a given wealth (through minting) and approve the vault
  await mockToken.mintTo(investor.address, firstStakerWealth);
  await mockToken.connect(investor).approve(vault.address, firstStakerWealth);

  return await vault.connect(investor).stake(mockToken.address, amountToStake);
};

export const changeRate = async (kyber: MockKyberNetworkProxy, token: any, rate: number) => {
  await kyber.setRate(token.address, rate);
};

export const getTokens = async (user: string, token: string, whale: string, amount: BigNumber) => {
  const contract = await ethers.getContractAt(ERC20.abi, token);

  const balance = await contract.balanceOf(whale);
  expect(balance).to.be.gte(amount);

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
};

export const matchState = (
  state1: any,
  supported: boolean,
  locked: boolean,
  baseFee: BigNumber,
  fixedFee: BigNumber,
  netLoans: BigNumber,
  minimumMargin: BigNumber,
  insuranceReserveBalance: BigNumber,
  optimalRatio: BigNumber,
) => {
  expect(state1.supported).to.equal(supported);
  expect(state1.locked).to.equal(locked);
  expect(state1.baseFee).to.equal(baseFee);
  expect(state1.fixedFee).to.equal(fixedFee);
  expect(state1.netLoans).to.equal(netLoans);
  expect(state1.minimumMargin).to.equal(minimumMargin);
  expect(state1.insuranceReserveBalance).to.equal(insuranceReserveBalance);
  expect(state1.optimalRatio).to.equal(optimalRatio);
};

export function expandTo18Decimals(n: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(18));
}

export function expandToNDecimals(n: number, decimals: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(decimals));
}

export function equalWithTolerance(a: BigNumber, b: BigNumber, decimals: number) {
  expect(a).to.be.above(b.sub(BigNumber.from(10).pow(decimals)));
  expect(a).to.be.below(b.add(BigNumber.from(10).pow(decimals)));
}

export const matchStateTokenisedVault = (state1: any, state2: any) => {
  expect(state1.netLoans).to.equal(state2.netLoans);
  expect(state1.latestRepay).to.equal(state2.latestRepay);
  expect(state1.currentProfits).to.equal(state2.currentProfits);
  expect(state1.blockTimestamp).to.equal(state2.blockTimestamp);
  expect(state1.balance).to.equal(state2.balance);
};

export const verifyStateTokenisedVault = async (vault: MockTokenisedVault, native: MockToken, state2: any) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  expect(netLoans).to.equal(state2.netLoans);
  expect(latestRepay).to.equal(state2.latestRepay);
  expect(currentProfits).to.equal(state2.currentProfits);
  expect(await vault.time()).to.equal(state2.blockTimestamp);
  expect(await native.balanceOf(vault.address)).to.equal(state2.balance);
};

export const increaseLoans = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  let newLoans = netLoans.add(amount);
  await vault.setAccounting(newLoans, latestRepay, currentProfits);
  const state = {
    netLoans: netLoans.add(amount),
    latestRepay: latestRepay,
    currentProfits: currentProfits,
    blockTimestamp: initialTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const decreaseLoans = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  let newLoans = BigNumber.from(0);
  if (netLoans.gt(amount)) newLoans = netLoans.sub(amount);
  await vault.setAccounting(newLoans, latestRepay, currentProfits);
  const state = {
    netLoans: netLoans.sub(amount),
    latestRepay: latestRepay,
    currentProfits: currentProfits,
    blockTimestamp: initialTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const increaseLatestRepay = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  let newLatestRepay = latestRepay.add(amount);
  await vault.setAccounting(netLoans, newLatestRepay, currentProfits);
  const state = {
    netLoans: netLoans,
    latestRepay: newLatestRepay,
    currentProfits: currentProfits,
    blockTimestamp: initialTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const increaseCurrentProfits = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  let newProfits = currentProfits.add(amount);
  await vault.setAccounting(currentProfits, latestRepay, newProfits);
  const state = {
    netLoans: netLoans,
    latestRepay: latestRepay,
    currentProfits: currentProfits.add(amount),
    blockTimestamp: initialTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const decreaseCurrentProfits = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  let newProfits = currentProfits.sub(amount);
  await vault.setAccounting(netLoans, latestRepay, newProfits);
  const state = {
    netLoans: netLoans,
    latestRepay: latestRepay,
    currentProfits: currentProfits.sub(amount),
    blockTimestamp: initialTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const increaseBalance = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const initialBalance = await native.balanceOf(vault.address);
  const initialTime = await vault.time();
  await native.mintTo(vault.address, amount);
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const state = {
    netLoans: netLoans,
    latestRepay: latestRepay,
    currentProfits: currentProfits,
    blockTimestamp: initialTime,
    balance: initialBalance.add(amount),
  };
  await verifyStateTokenisedVault(vault, native, state);
};

export const advanceTime = async (vault: MockTokenisedVault, native: MockToken, amount: BigNumber) => {
  const netLoans = await vault.netLoans();
  const latestRepay = await vault.latestRepay();
  const currentProfits = await vault.currentProfits();
  const newTime = (await vault.time()).add(amount);
  const initialBalance = await native.balanceOf(vault.address);
  await vault.advanceTime(amount);
  const state = {
    netLoans: netLoans,
    latestRepay: latestRepay,
    currentProfits: currentProfits,
    blockTimestamp: newTime,
    balance: initialBalance,
  };
  await verifyStateTokenisedVault(vault, native, state);
};
