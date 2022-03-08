import { artifacts, ethers, waffle } from "hardhat";
import { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../types";
import { Liquidator } from "../../src/types/Liquidator";
import { checkLiquidateSingle } from "./Liquidator.liquidateSingle";
import { checkMarginCall } from "./Liquidator.marginCall";
import { checkPurchaseAssets } from "./Liquidator.purchaseAssets";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("Liquidator", function () {
    beforeEach(async function () {
      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>await waffle.deployContract(this.signers.admin, liquidatorArtifact, []);
    });

    checkLiquidateSingle();
    checkMarginCall();
    checkPurchaseAssets();
  });
});
