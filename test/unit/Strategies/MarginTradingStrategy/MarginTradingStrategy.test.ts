import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import { MockKyberNetworkProxy } from "../../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../../src/types/MockWETH";
import { MarginTradingStrategy } from "../../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";
import { MockTaxedToken } from "../../../../src/types/MockTaxedToken";
import { Console } from "console";

import { checkRiskFactor } from "./MarginTradingStrategy.riskFactor";
import { checkOpenPosition } from "./MarginTradingStrategy.openPosition";
import { checkClosePosition } from "./MarginTradingStrategy.closePosition";
import { checkEditPosition } from "./MarginTradingStrategy.editPosition";
import { checkDeadline } from "./MarginTradingStrategy.deadline";
import { checkLiquidate } from "./MarginTradingStrategy.liquidate";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("MarginTradingStrategy", function () {
    beforeEach(async function () {
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

      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>(
        await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
          "0x0000000000000000000000000000000000000000",
        ])
      );

      const mtsArtifact: Artifact = await artifacts.readArtifact("MarginTradingStrategy");
      this.marginTradingStrategy = <MarginTradingStrategy>(
        await waffle.deployContract(this.signers.admin, mtsArtifact, [
          this.vault.address,
          this.liquidator.address,
          this.mockKyberNetworkProxy.address,
        ])
      );

      const tknArtifact: Artifact = await artifacts.readArtifact("MockTaxedToken");
      this.mockTaxedToken = <MockTaxedToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, ["Dai Stablecoin", "DAI", 18])
      );

      await this.vault.addStrategy(this.marginTradingStrategy.address);
      await this.marginTradingStrategy.setRiskFactor(this.mockTaxedToken.address, 3000);
      await this.marginTradingStrategy.setRiskFactor(this.mockWETH.address, 4000);

      // mint tokens
      await this.mockWETH.mintTo(this.mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
      await this.mockTaxedToken.mintTo(this.mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
    });

    checkRiskFactor();
    checkOpenPosition();
    checkClosePosition();
    // checkEditPosition(); // TODO: not completed
    checkDeadline();
    checkLiquidate();
  });
});
