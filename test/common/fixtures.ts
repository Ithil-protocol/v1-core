import { artifacts, ethers } from "hardhat";
import { Fixture, deployContract } from "ethereum-waffle";

import { tokens } from "./mainnet";
import type { Artifact } from "hardhat/types";
import type { ERC20 } from "../../src/types/ERC20";

import { Vault } from "../../src/types/Vault";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

interface VaultFixture {
  WETH: ERC20;
  admin: SignerWithAddress;
  investor: SignerWithAddress;
  trader: SignerWithAddress;
  createVault(): Promise<Vault>;
}

export const vaultFixture: Fixture<VaultFixture> = async function (): Promise<VaultFixture> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin = signers[0];
  const investor = signers[1];
  const trader = signers[2];

  const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
  const WETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

  return {
    WETH,
    admin,
    investor,
    trader,
    createVault: async () => {
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      const vault = <Vault>await deployContract(admin, vaultArtifact, [WETH.address]);
      return vault;
    },
  };
};
