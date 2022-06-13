import { artifacts, ethers } from "hardhat";
import { BigNumber } from "ethers";
import { Fixture } from "ethereum-waffle";

import { tokens } from "./mainnet";
import { getTokens } from "./utils";
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
  const vaultFactory = await ethers.getContractFactory("Vault");
  console.log("Inside vault fixture");
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const admin = signers[0];
  const investor = signers[1];
  const trader = signers[2];

  const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
  const WETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

  console.log("Inside vault fixture: returning");
  return {
    WETH,
    admin,
    investor,
    trader,
    createVault: async () => {
      console.log("Inside vault fixture: deploying");
      const vault = (await vaultFactory.deploy(WETH.address)) as Vault;
      console.log("Inside vault fixture: deployed");
      return vault;
    },
  };
};
