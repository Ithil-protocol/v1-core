import { artifacts, ethers } from "hardhat";
import { Fixture, deployContract } from "ethereum-waffle";
import type { Artifact } from "hardhat/types";
import { MockWETH } from "../../src/types/MockWETH";
import { MockToken } from "../../src/types/MockToken";
import { MockYearnRegistry } from "../../src/types/MockYearnRegistry";

import { Vault } from "../../src/types/Vault";
import { Liquidator } from "../../src/types/Liquidator";
import { MarginTradingStrategy } from "../../src/types/MarginTradingStrategy";
import { TestStrategy } from "../../src/types/TestStrategy";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { YearnStrategy } from "../../src/types/YearnStrategy";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

interface MockVaultFixture {
  mockWETH: MockWETH;
  admin: SignerWithAddress;
  investor1: SignerWithAddress;
  investor2: SignerWithAddress;
  createVault(): Promise<Vault>;
}

interface MockMarginTradingStrategyFixture {
  mockWETH: MockWETH;
  admin: SignerWithAddress;
  trader1: SignerWithAddress;
  trader2: SignerWithAddress;
  liquidator: SignerWithAddress;
  vault: Vault;
  mockKyberNetworkProxy: MockKyberNetworkProxy;
  liquidatorContract: Liquidator;
  createStrategy(): Promise<MarginTradingStrategy>;
}

interface MockTestStrategyFixture {
  mockWETH: MockWETH;
  admin: SignerWithAddress;
  trader1: SignerWithAddress;
  trader2: SignerWithAddress;
  liquidator: SignerWithAddress;
  vault: Vault;
  liquidatorContract: Liquidator;
  createStrategy(): Promise<TestStrategy>;
}

interface MockYearnStrategyFixture {
  mockWETH: MockWETH;
  admin: SignerWithAddress;
  trader1: SignerWithAddress;
  trader2: SignerWithAddress;
  liquidator: SignerWithAddress;
  vault: Vault;
  mockYearnRegistry: MockYearnRegistry;
  liquidatorContract: Liquidator;
  createStrategy(): Promise<YearnStrategy>;
}

export const mockVaultFixture: Fixture<MockVaultFixture> = async function (): Promise<MockVaultFixture> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin = signers[0];
  const investor1 = signers[1];
  const investor2 = signers[2];
  const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
  const mockWETH = <MockWETH>await deployContract(admin, wethArtifact, []);

  return {
    mockWETH,
    admin,
    investor1,
    investor2,
    createVault: async () => {
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      const vault = <Vault>await deployContract(admin, vaultArtifact, [mockWETH.address]);
      return vault;
    },
  };
};

export const mockMarginTradingFixture: Fixture<MockMarginTradingStrategyFixture> =
  async function (): Promise<MockMarginTradingStrategyFixture> {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const admin = signers[0];
    const trader1 = signers[3];
    const trader2 = signers[4];
    const liquidator = signers[5];

    const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
    const mockKyberNetworkProxy = <MockKyberNetworkProxy>await deployContract(admin, kyberArtifact, []);

    const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
    const mockWETH = <MockWETH>await deployContract(admin, wethArtifact, []);

    const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
    const vault = <Vault>await deployContract(admin, vaultArtifact, [mockWETH.address]);

    const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
    const liquidatorContract = <Liquidator>(
      await deployContract(admin, liquidatorArtifact, ["0x0000000000000000000000000000000000000000"])
    );

    return {
      mockWETH,
      admin,
      trader1,
      trader2,
      liquidator,
      vault,
      mockKyberNetworkProxy,
      liquidatorContract,
      createStrategy: async () => {
        const mtsArtifact: Artifact = await artifacts.readArtifact("MarginTradingStrategy");
        const strategy = <MarginTradingStrategy>(
          await deployContract(admin, mtsArtifact, [
            vault.address,
            liquidatorContract.address,
            mockKyberNetworkProxy.address,
          ])
        );
        await vault.addStrategy(strategy.address);
        return strategy;
      },
    };
  };

export const mockYearnFixture: Fixture<MockYearnStrategyFixture> =
  async function (): Promise<MockYearnStrategyFixture> {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const admin = signers[0];
    const trader1 = signers[3];
    const trader2 = signers[4];
    const liquidator = signers[5];

    const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
    const mockWETH = <MockWETH>await deployContract(admin, wethArtifact, []);

    const tknArtifact: Artifact = await artifacts.readArtifact("MockToken");
    const mockToken = <MockToken>await deployContract(admin, tknArtifact, ["Dai Stablecoin", "DAI", 18]);

    const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
    const vault = <Vault>await deployContract(admin, vaultArtifact, [mockWETH.address]);

    const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
    const liquidatorContract = <Liquidator>(
      await deployContract(admin, liquidatorArtifact, ["0x0000000000000000000000000000000000000000"])
    );

    const yearnArtifact: Artifact = await artifacts.readArtifact("MockYearnRegistry");
    const mockYearnRegistry = <MockYearnRegistry>await deployContract(admin, yearnArtifact, []);

    return {
      mockWETH,
      admin,
      trader1,
      trader2,
      liquidator,
      vault,
      mockYearnRegistry,
      liquidatorContract,
      createStrategy: async () => {
        const mtsArtifact: Artifact = await artifacts.readArtifact("YearnStrategy");
        const strategy = <YearnStrategy>(
          await deployContract(admin, mtsArtifact, [
            vault.address,
            liquidatorContract.address,
            mockYearnRegistry.address,
          ])
        );
        await vault.addStrategy(strategy.address);
        return strategy;
      },
    };
  };

export const mockTestFixture: Fixture<MockTestStrategyFixture> = async function (): Promise<MockTestStrategyFixture> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin = signers[0];
  const trader1 = signers[3];
  const trader2 = signers[4];
  const liquidator = signers[5];

  const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
  const mockWETH = <MockWETH>await deployContract(admin, wethArtifact, []);

  const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
  const vault = <Vault>await deployContract(admin, vaultArtifact, [mockWETH.address]);

  const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
  const liquidatorContract = <Liquidator>(
    await deployContract(admin, liquidatorArtifact, ["0x0000000000000000000000000000000000000000"])
  );

  return {
    mockWETH,
    admin,
    trader1,
    trader2,
    liquidator,
    vault,
    liquidatorContract,
    createStrategy: async () => {
      const mtsArtifact: Artifact = await artifacts.readArtifact("TestStrategy");
      const strategy = <TestStrategy>(
        await deployContract(admin, mtsArtifact, [vault.address, liquidatorContract.address])
      );
      await vault.addStrategy(strategy.address);
      return strategy;
    },
  };
};
