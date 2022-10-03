import { artifacts, ethers } from "hardhat";
import { Fixture, deployContract } from "ethereum-waffle";
import type { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { tokens } from "../../../common/mainnet";
import type { ERC20 } from "../../../../src/types/ERC20";
import { MarginTradingStrategy } from "../../../../src/types/MarginTradingStrategy";
import { Vault } from "../../../../src/types/Vault";
import { Liquidator } from "../../../../src/types/Liquidator";
import { kyberNetwork } from "./constants";

interface MarginTradingStrategyFixture {
  WETH: ERC20;
  admin: SignerWithAddress;
  trader1: SignerWithAddress;
  trader2: SignerWithAddress;
  liquidator: SignerWithAddress;
  vault: Vault;
  liquidatorContract: Liquidator;
  createStrategy(): Promise<MarginTradingStrategy>;
}

export const marginTradingFixture: Fixture<MarginTradingStrategyFixture> =
  async function (): Promise<MarginTradingStrategyFixture> {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const admin = signers[0];
    const trader1 = signers[3];
    const trader2 = signers[4];
    const liquidator = signers[5];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    const WETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

    const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
    const vault = <Vault>await deployContract(admin, vaultArtifact, [WETH.address]);
    const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
    const liquidatorContract = <Liquidator>(
      await deployContract(admin, liquidatorArtifact, ["0x0000000000000000000000000000000000000000"])
    );

    return {
      WETH,
      admin,
      trader1,
      trader2,
      liquidator,
      vault,
      liquidatorContract,
      createStrategy: async () => {
        const mtsArtifact: Artifact = await artifacts.readArtifact("MarginTradingStrategy");
        const strategy = <MarginTradingStrategy>(
          await deployContract(admin, mtsArtifact, [
            vault.address,
            liquidatorContract.address,
            "0x0000000000000000000000000000000000000000",
            kyberNetwork,
          ])
        );
        await vault.addStrategy(strategy.address);
        return strategy;
      },
    };
  };
