import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../../types";
import { Artifact } from "hardhat/types";
import { Liquidator } from "../../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../../src/types/MockWETH";
import { Vault } from "../../../../src/types/Vault";
import { TestStrategy } from "../../../../src/types/TestStrategy";

import { checkSetRiskFactor } from "./TestStrategy.setRiskFactor";
import { checkGetPosition } from "./TestStrategy.getPosition";
import { checkTotalAllowance } from "./TestStrategy.totalAllowance";
import { checkVaultAddress } from "./TestStrategy.vaultAddress";
import { checkOpenPosition } from "./TestStrategy.openPosition";
import { checkClosePosition } from "./TestStrategy.closePosition";
import { checkEditPosition } from "./TestStrategy.editPosition";
import { checkStatus } from "./TestStrategy.status";
import { checkArbitraryBorrow } from "./TestStrategy.arbitraryBorrow";
import { checkArbitraryRepay } from "./TestStrategy.arbitraryRepay";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("TestStrategy", function () {
    beforeEach(async function () {
      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>(
        await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
          "0x0000000000000000000000000000000000000000",
        ])
      );

      const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
        await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      );

      const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>await waffle.deployContract(this.signers.admin, wethArtifact, []);

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [
        this.mockWETH.address,
        // this.signers.admin.address,
      ]);

      const usArtifact: Artifact = await artifacts.readArtifact("TestStrategy");
      this.TestStrategy = <TestStrategy>(
        await waffle.deployContract(this.signers.admin, usArtifact, [this.vault.address, this.liquidator.address])
      );
      await this.vault.addStrategy(this.TestStrategy.address);
    });

    // checkSetRiskFactor();
    // checkGetPosition();
    // checkTotalAllowance();
    // checkVaultAddress();
    // checkOpenPosition();
    // checkClosePosition();
    // checkEditPosition();
    checkStatus();
    checkArbitraryBorrow();
    checkArbitraryRepay();
  });
});
