import { artifacts, ethers } from "hardhat";
import { Fixture, deployContract } from "ethereum-waffle";
import type { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { tokens } from "./mainnet";
import type { ERC20 } from "../../src/types/ERC20";
import { Vault } from "../../src/types/Vault";

interface VaultFixture {
  WETH: ERC20;
  admin: SignerWithAddress;
  investor1: SignerWithAddress;
  investor2: SignerWithAddress;
  createVault(): Promise<Vault>;
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
