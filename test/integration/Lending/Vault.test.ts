import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";

import { tokens } from "../../common/mainnet";
import { getTokens } from "../../common/utils";

import type { ERC20 } from "../../../src/types/ERC20";
import type { Vault } from "../../../src/types/Vault";

import { checkWhitelist, checkStaking } from "./Vault";

describe("Lending integration tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("Lending", function () {
    beforeEach(async function () {
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>(
        await waffle.deployContract(this.signers.admin, vaultArtifact, [
          tokens.WETH.address,
          this.signers.admin.address,
        ])
      );

      const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
      this.token = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

      this.tokensAmount = ethers.utils.parseUnits("1.0", tokens.WETH.decimals);

      await getTokens(this.signers.investor.address, tokens.WETH.address, tokens.WETH.whale, this.tokensAmount);
    });

    checkWhitelist();
    checkStaking();
  });
});
