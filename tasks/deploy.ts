import * as fs from "fs";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";

import { chainIds } from "../constants";

import { Liquidator } from "../src/types/Liquidator";
import { Liquidator__factory } from "../src/types/factories/Liquidator__factory";

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

task("deploy", "Deploys the mock contracts", async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
  // MockKyberNetworkProxy
  const kyberFactory: MockKyberNetworkProxy__factory = <MockKyberNetworkProxy__factory>(
    await hre.ethers.getContractFactory("MockKyberNetworkProxy")
  );
  const kyber: MockKyberNetworkProxy = <MockKyberNetworkProxy>await kyberFactory.deploy();
  await kyber.deployed();
  console.log("MockKyberNetworkProxy deployed to address: ", kyber.address);

  // MockYearnRegistry
  const yearnFactory: MockYearnRegistry__factory = <MockYearnRegistry__factory>(
    await hre.ethers.getContractFactory("MockYearnRegistry")
  );
  const yearn: MockYearnRegistry = <MockYearnRegistry>await yearnFactory.deploy();
  await yearn.deployed();
  console.log("MockYearnRegistry deployed to address: ", yearn.address);

  // MockWETH
  const wethFactory: MockWETH__factory = <MockWETH__factory>await hre.ethers.getContractFactory("MockWETH");
  const weth: MockWETH = <MockWETH>await wethFactory.deploy();
  await weth.deployed();
  console.log("MockWETH deployed to address: ", weth.address);

  // MockTaxedToken
  const tknFactory: MockTaxedToken__factory = <MockTaxedToken__factory>(
    await hre.ethers.getContractFactory("MockTaxedToken")
  );
  const tkn: MockTaxedToken = <MockTaxedToken>await tknFactory.deploy("Dai Stablecoin", "DAI", 18);
  await tkn.deployed();
  console.log("MockTaxedToken deployed to address: ", tkn.address);

  // Vault
  const vaultFactory: Vault__factory = <Vault__factory>await hre.ethers.getContractFactory("Vault");
  const vault: Vault = <Vault>await vaultFactory.deploy(weth.address); //todo: insert treasury
  await vault.deployed();
  console.log("Vault deployed to address: ", vault.address);

  // Liquidator
  const liquidatorFactory: Liquidator__factory = <Liquidator__factory>await hre.ethers.getContractFactory("Liquidator");
  const liquidator: Liquidator = <Liquidator>(
    await liquidatorFactory.deploy("0x0000000000000000000000000000000000000000")
  );
  await liquidator.deployed();
  console.log("Liquidator deployed to address: ", liquidator.address);

  // MarginTradingStrategy
  const mtsFactory: MarginTradingStrategy__factory = <MarginTradingStrategy__factory>(
    await hre.ethers.getContractFactory("MarginTradingStrategy")
  );
  const mts: MarginTradingStrategy = <MarginTradingStrategy>(
    await mtsFactory.deploy(vault.address, liquidator.address, kyber.address)
  );
  await mts.deployed();
  console.log("MarginTradingStrategy deployed to address: ", mts.address);

  // YearnStrategy
  const ysFactory: YearnStrategy__factory = <YearnStrategy__factory>(
    await hre.ethers.getContractFactory("YearnStrategy")
  );
  const ys: YearnStrategy = <YearnStrategy>await ysFactory.deploy(
    vault.address, // vault
    liquidator.address, // liquidator
    yearn.address, // registry
  );
  await ys.deployed();
  console.log("YearnStrategy deployed to address: ", ys.address);

  // write addresses to a file
  const addressesFile = {
    name: "Deployed Contracts",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    chainId: chainIds[hre.network.name],
    addresses: {
      MockKyberNetworkProxy: kyber.address,
      MockYearnRegistry: yearn.address,
      MockWETH: weth.address,
      MockTaxedToken: tkn.address,
      Vault: vault.address,
      Liquidator: liquidator.address,
      MarginTradingStrategy: mts.address,
      YearnStrategy: ys.address,
    },
  };
  const str = JSON.stringify(addressesFile, null, 4);
  fs.writeFileSync("deployments/addresses.json", str, "utf8");

  // write tokens to a file
  const tokens = {
    name: "Supported Tokens",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    tokens: [
      {
        name: "DAI Stablecoin",
        address: tkn.address,
        symbol: "DAI",
        decimals: 18,
        chainId: chainIds[hre.network.name],
        logoURI:
          "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0x6B175474E89094C44Da98b954EedeAC495271d0F/logo.png",
      },
      {
        name: "Wrapped Ether",
        address: weth.address,
        symbol: "WETH",
        decimals: 18,
        chainId: chainIds[hre.network.name],
        logoURI:
          "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2/logo.png",
      },
    ],
  };
  const tokensFile = JSON.stringify(tokens, null, 4);
  fs.writeFileSync("deployments/tokenlist.json", tokensFile, "utf8");
});
