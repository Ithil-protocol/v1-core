import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Vault } from "../src/types/Vault";
import { Vault__factory } from "../src/types/factories/Vault__factory";

import { MarginTradingStrategy } from "../src/types/MarginTradingStrategy";
import { MarginTradingStrategy__factory } from "../src/types/factories/MarginTradingStrategy__factory";

import { YearnStrategy } from "../src/types/YearnStrategy";
import { YearnStrategy__factory } from "../src/types/factories/YearnStrategy__factory";

import { MockKyberNetworkProxy } from "../src/types/MockKyberNetworkProxy";
import { MockKyberNetworkProxy__factory } from "../src/types/factories/MockKyberNetworkProxy__factory";

import { MockYearnRegistry } from "../src/types/MockYearnRegistry";
import { MockYearnRegistry__factory } from "../src/types/factories/MockYearnRegistry__factory";

import { MockWETH } from "../src/types/MockWETH";
import { MockWETH__factory } from "../src/types/factories/MockWETH__factory";

import { MockTaxedToken } from "../src/types/MockTaxedToken";
import { MockTaxedToken__factory } from "../src/types/factories/MockTaxedToken__factory";

task("deploy").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  // MockKyberNetworkProxy
  const kyberFactory: MockKyberNetworkProxy__factory = <MockKyberNetworkProxy__factory>(
    await ethers.getContractFactory("MockKyberNetworkProxy")
  );
  const kyber: MockKyberNetworkProxy = <MockKyberNetworkProxy>await kyberFactory.deploy();
  await kyber.deployed();
  console.log("MockKyberNetworkProxy deployed to address: ", kyber.address);

  // MockYearnRegistry
  const yearnFactory: MockYearnRegistry__factory = <MockYearnRegistry__factory>(
    await ethers.getContractFactory("MockYearnRegistry")
  );
  const yearn: MockYearnRegistry = <MockYearnRegistry>await yearnFactory.deploy();
  await yearn.deployed();
  console.log("MockYearnRegistry deployed to address: ", yearn.address);

  // MockWETH
  const wethFactory: MockWETH__factory = <MockWETH__factory>await ethers.getContractFactory("MockWETH");
  const weth: MockWETH = <MockWETH>await wethFactory.deploy(kyber.address);
  await weth.deployed();
  console.log("MockWETH deployed to address: ", weth.address);

  // MockTaxedToken
  const tknFactory: MockTaxedToken__factory = <MockTaxedToken__factory>(
    await ethers.getContractFactory("MockTaxedToken")
  );
  const tkn: MockTaxedToken = <MockTaxedToken>await tknFactory.deploy("Dai Stablecoin", "DAI", kyber.address);
  await tkn.deployed();
  console.log("MockTaxedToken deployed to address: ", tkn.address);

  // Vault
  const vaultFactory: Vault__factory = <Vault__factory>await ethers.getContractFactory("Vault");
  const vault: Vault = <Vault>await vaultFactory.deploy(weth.address);
  await vault.deployed();
  console.log("Vault deployed to address: ", vault.address);

  // MarginTradingStrategy
  const mtsFactory: MarginTradingStrategy__factory = <MarginTradingStrategy__factory>(
    await ethers.getContractFactory("MarginTradingStrategy")
  );
  const mts: MarginTradingStrategy = <MarginTradingStrategy>await mtsFactory.deploy(kyber.address, vault.address);
  await mts.deployed();
  console.log("MarginTradingStrategy deployed to address: ", mts.address);

  // MarginTradingStrategy
  const ysFactory: YearnStrategy__factory = <YearnStrategy__factory>await ethers.getContractFactory("YearnStrategy");
  const ys: YearnStrategy = <YearnStrategy>await ysFactory.deploy(yearn.address, vault.address);
  await ys.deployed();
  console.log("YearnStrategy deployed to address: ", ys.address);
});
