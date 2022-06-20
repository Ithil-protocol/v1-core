import { artifacts, ethers } from "hardhat";
import { Fixture, deployContract } from "ethereum-waffle";

import { tokens, yearnRegistry, yearnPartnerTracker, yearnPartnerId } from "./mainnet";
import type { Artifact } from "hardhat/types";
import type { ERC20 } from "../../src/types/ERC20";

import { kyberNetwork } from "./mainnet";
import { Vault } from "../../src/types/Vault";
import { Liquidator } from "../../src/types/Liquidator";
import { MarginTradingStrategy } from "../../src/types/MarginTradingStrategy";
import { YearnStrategy } from "../../src/types/YearnStrategy";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

interface VaultFixture {
  WETH: ERC20;
  admin: SignerWithAddress;
  investor1: SignerWithAddress;
  investor2: SignerWithAddress;
  createVault(): Promise<Vault>;
}

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

interface YearnStrategyFixture {
  WETH: ERC20;
  admin: SignerWithAddress;
  trader1: SignerWithAddress;
  trader2: SignerWithAddress;
  liquidator: SignerWithAddress;
  vault: Vault;
  liquidatorContract: Liquidator;
  createStrategy(): Promise<YearnStrategy>;
}

export const vaultFixture: Fixture<VaultFixture> = async function (): Promise<VaultFixture> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin = signers[0];
  const investor1 = signers[1];
  const investor2 = signers[2];

  const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
  const WETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

  return {
    WETH,
    admin,
    investor1,
    investor2,
    createVault: async () => {
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      const vault = <Vault>await deployContract(admin, vaultArtifact, [WETH.address]);
      return vault;
    },
  };
};

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
          await deployContract(admin, mtsArtifact, [vault.address, liquidatorContract.address, kyberNetwork])
        );
        await vault.addStrategy(strategy.address);
        return strategy;
      },
    };
  };

export const yearnFixture: Fixture<YearnStrategyFixture> = async function (): Promise<YearnStrategyFixture> {
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
      const ysArtifact: Artifact = await artifacts.readArtifact("YearnStrategy");
      const strategy = <YearnStrategy>(
        await deployContract(admin, ysArtifact, [
          vault.address,
          liquidatorContract.address,
          yearnRegistry,
          yearnPartnerId,
          yearnPartnerTracker,
        ])
      );
      await vault.addStrategy(strategy.address);
      return strategy;
    },
  };
};
