import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";

import { checkRiskFactors } from "./Liquidable.riskFactors";
import { checkComputePairRiskFactor } from "./Liquidable.computePairRiskFactor";
import { checkComputeLiquidationScore } from "./Liquidable.computeLiquidationScore";
import { checkForcefullyClose } from "./Liquidable.forcefullyClose";
import { checkForcefullyDelete } from "./Liquidable.forcefullyDelete";
import { checkModifyCollateralAndOwner } from "./Liquidable.modifyCollateralAndOwner";
import { Artifact } from "hardhat/types";
import { Vault } from "../../../src/types/Vault";
import { Liquidator } from "../../../src/types/Liquidator";
import { Liquidable } from "../../../src/types/Liquidable";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("Liquidable", function () {
    beforeEach(async function () {
      // const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      // this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
      //   await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      // );
      // const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      // this.mockWETH = <MockWETH>(
      //   await waffle.deployContract(this.signers.admin, wethArtifact, [this.mockKyberNetworkProxy.address])
      // );
      // const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      // this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.mockWETH.address]);
      // console.log("1", this.vault.address);
      // const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      // this.liquidator = <Liquidator>await waffle.deployContract(this.signers.admin, liquidatorArtifact);
      // console.log("2", this.liquidator.address);
      // const liquidableArtifact: Artifact = await artifacts.readArtifact("Liquidable");
      // this.liquidable = <Liquidable>(
      //   await waffle.deployContract(this.signers.admin, liquidableArtifact, [
      //     this.liquidator.address,
      //     this.vault.address
      //   ])
      // );
      // console.log("3", this.liquidable.address);
      // this.vault.addStrategy(this.liquidable.address);
    });

    checkRiskFactors();
    checkComputePairRiskFactor();
    checkComputeLiquidationScore();
    checkForcefullyClose();
    checkForcefullyDelete();
    checkModifyCollateralAndOwner();
  });
});
