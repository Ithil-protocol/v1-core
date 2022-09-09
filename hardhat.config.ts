import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@tenderly/hardhat-tenderly";
import "@typechain/hardhat";
import "hardhat-abi-exporter";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "hardhat-spdx-license-identifier";
import "solidity-coverage";

import { chainIds } from "./constants";
import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const config: HardhatUserConfig = {
  abiExporter: {
    path: "./abi",
    clear: false,
    flat: true,
    // only: [],
    // except: []
  },
  defaultNetwork: "hardhat",
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: ["contracts/mocks/", "contracts/libraries/"],
    src: "./contracts",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  networks: {
    hardhat: {
      chainId: chainIds.hardhat,
      forking: {
        enabled: process.env.FORKING ? true : false,
        url: "https://eth-mainnet.g.alchemy.com/v2/" + process.env.ALCHEMY_API_KEY,
        blockNumber: 14967494,
      },
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.12",
    settings: {
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT || "",
    username: process.env.TENDERLY_USERNAME || "",
  },
  mocha: {
    timeout: 60000,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: false,
    strict: false,
    only: [
      "Vault",
      "BaseStrategy",
      "Liquidator",
      "MarginTradingStrategy",
      "TestStrategy",
      "YearnStrategy",
      "EulerStrategy",
    ],
  },
};

export default config;
