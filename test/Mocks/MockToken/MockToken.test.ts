import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";
import { Artifact } from "hardhat/types";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockToken } from "../../../src/types/MockToken";

import { checkToggleBlock } from "./MockToken.toggleBlock";
import { checkSetThrottlingPeriod } from "./MockToken.setThrottlingPeriod";
import { checkMintTo } from "./MockToken.mintTo";
import { checkMint } from "./MockToken.mint";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("MockToken", function () {
    beforeEach(async function () {
      const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
        await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      );

      const tknArtifact: Artifact = await artifacts.readArtifact("MockToken");
      this.mockToken = <MockToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          "Dai Stablecoin",
          "DAI",
          this.mockKyberNetworkProxy.address,
        ])
      );
    });
    checkToggleBlock();
    checkSetThrottlingPeriod();
    checkMintTo();
    checkMint();
  });
});
