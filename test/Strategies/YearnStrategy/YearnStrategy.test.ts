import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { Signers } from "../../types";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { YearnStrategy } from "../../../src/types/YearnStrategy";
import { MockTaxedToken } from "../../../src/types/MockTaxedToken";
import { MockYearnRegistry } from "../../../src/types/MockYearnRegistry";
import { Liquidator } from "../../../src/types/Liquidator";

import { checkClosePosition } from "./YearnStrategy.closePosition";
import { checkEditPosition } from "./YearnStrategy.editPosition";
import { checkOpenPosition } from "./YearnStrategy.openPosition";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("YearnStrategy", function () {
    beforeEach(async function () {
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

      const yearnArtifact: Artifact = await artifacts.readArtifact("MockYearnRegistry");
      this.mockYearnRegistry = <MockYearnRegistry>await waffle.deployContract(this.signers.admin, yearnArtifact, []);

      //TODO: should deploy mockYearnRegistry, first

      const ysArtifact: Artifact = await artifacts.readArtifact("YearnStrategy");
      this.yearnStrategy = <YearnStrategy>(
        await waffle.deployContract(this.signers.admin, ysArtifact, [
          this.mockYearnRegistry,
          this.mockKyberNetworkProxy.address,
          this.vault.address,
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

      await this.vault.addStrategy(this.yearnStrategy.address);
    });

    // checkOpenPosition();
    // checkClosePosition();
    // checkEditPosition(); TODO:
  });
});
