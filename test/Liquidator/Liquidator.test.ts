import { artifacts, ethers, waffle } from "hardhat";
import { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../types";
import { Liquidator } from "../../src/types/Liquidator";
import { checkLiquidateSingle } from "./Liquidator.liquidateSingle";
import { checkMarginCall } from "./Liquidator.marginCall";
import { checkPurchaseAssets } from "./Liquidator.purchaseAssets";
import { Vault } from "../../src/types/Vault";
import { MockWETH } from "../../src/types/MockWETH";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockTaxedToken } from "../../src/types/MockTaxedToken";
import { MarginTradingStrategy } from "../../src/types/MarginTradingStrategy";

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

      const mtsArtifact: Artifact = await artifacts.readArtifact("MarginTradingStrategy");
      this.marginTradingStrategy = <MarginTradingStrategy>(
        await waffle.deployContract(this.signers.admin, mtsArtifact, [
          this.mockKyberNetworkProxy.address,
          this.vault.address,
          this.liquidator.address,
        ])
      );

      const tknArtifact: Artifact = await artifacts.readArtifact("MockTaxedToken");
      this.mockTaxedToken = <MockTaxedToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          "Dai Stablecoin",
          "DAI",
          this.mockKyberNetworkProxy.address,
        ])
      );

      await this.vault.addStrategy(this.marginTradingStrategy.address);
    });

    checkLiquidateSingle();
    checkMarginCall();
    checkPurchaseAssets();
  });
});
