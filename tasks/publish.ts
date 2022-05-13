import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import addresses from "../deployments/addresses.json";

task(
  "publish",
  "Verifies the deployed contracts",
  async (taskArguments: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    // verify Vault
    await hre.run("verify:verify", {
      address: addresses["addresses"].Vault,
      constructorArguments: [addresses["addresses"].MockWETH],
    });

    // verify Liquidator
    await hre.run("verify:verify", {
      address: addresses["addresses"].Liquidator,
      constructorArguments: [],
    });

    // verify MarginTradingStrategy
    await hre.run("verify:verify", {
      address: addresses["addresses"].MarginTradingStrategy,
      constructorArguments: [
        addresses["addresses"].MockKyberNetworkProxy,
        addresses["addresses"].Vault,
        addresses["addresses"].Liquidator,
      ],
    });

    // verify YearnStrategy
    await hre.run("verify:verify", {
      address: addresses["addresses"].YearnStrategy,
      constructorArguments: [
        addresses["addresses"].MockYearnRegistry,
        addresses["addresses"].Vault,
        addresses["addresses"].Liquidator,
      ],
    });
  },
);
