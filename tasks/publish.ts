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
      constructorArguments: ["0x0000000000000000000000000000000000000000"],
    });

    // verify MarginTradingStrategy
    await hre.run("verify:verify", {
      address: addresses["addresses"].MarginTradingStrategy,
      constructorArguments: [
        addresses["addresses"].Vault,
        addresses["addresses"].Liquidator,
        addresses["addresses"].MockKyberNetworkProxy,
      ],
    });

    // verify YearnStrategy
    await hre.run("verify:verify", {
      address: addresses["addresses"].YearnStrategy,
      constructorArguments: [
        addresses["addresses"].Vault,
        addresses["addresses"].Liquidator,
        addresses["addresses"].MockYearnRegistry,
      ],
    });
  },
);
