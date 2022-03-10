import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";
import { Artifact } from "hardhat/types";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { Vault } from "../../../src/types/Vault";
import { UniversalStrategy } from "../../../src/types/UniversalStrategy";

import { checkSetRiskFactor } from "./UniversalStrategy.setRiskFactor";
import { checkGetPosition } from "./UniversalStrategy.getPosition";
import { checkTotalAllowance } from "./UniversalStrategy.totalAllowance";
import { checkVaultAddress } from "./UniversalStrategy.vaultAddress";
import { checkOpenPosition } from "./UniversalStrategy.openPosition";
import { checkClosePosition } from "./UniversalStrategy.closePosition";
import { checkEditPosition } from "./UniversalStrategy.editPosition";
import { checkQuote } from "./UniversalStrategy.quote";
import { checkArbitraryBorrow } from "./UniversalStrategy.arbitraryBorrow";
import { checkArbitraryRepay } from "./UniversalStrategy.arbitraryRepay";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("UniversalStrategy", function () {
    beforeEach(async function () {
      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>await waffle.deployContract(this.signers.admin, liquidatorArtifact, []);

      const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
        await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      );

      const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>(
        await waffle.deployContract(this.signers.admin, wethArtifact, [this.mockKyberNetworkProxy.address])
      );

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.mockWETH.address]);

      const usArtifact: Artifact = await artifacts.readArtifact("UniversalStrategy");
      this.universalStrategy = <UniversalStrategy>(
        await waffle.deployContract(this.signers.admin, usArtifact, [this.vault.address, this.liquidator.address])
      );
      await this.vault.addStrategy(this.universalStrategy.address);
    });

    // checkSetRiskFactor();
    // checkGetPosition();
    // checkTotalAllowance();
    // checkVaultAddress();
    // checkOpenPosition();
    // checkClosePosition();
    // checkEditPosition();
    checkQuote();
    checkArbitraryBorrow();
    checkArbitraryRepay();
  });
});
