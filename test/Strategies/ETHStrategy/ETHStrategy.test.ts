import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { Signers } from "../../types";
import { MockWETH } from "../../../src/types/MockWETH";
import { MockTaxedToken } from "../../../src/types/MockTaxedToken";
import { Liquidator } from "../../../src/types/Liquidator";
import { ETHStrategy } from "../../../src/types/ETHStrategy";

import { checkOpenPosition } from "./ETHStrategy.openPosition";
import { checkClosePosition } from "./ETHStrategy.closePosition";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("ETHStrategy", function () {
    beforeEach(async function () {
      const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>(
        await waffle.deployContract(this.signers.admin, wethArtifact, [this.signers.admin.address])
      );

      await this.signers.admin.sendTransaction({
        to: this.mockWETH.address,
        value: ethers.utils.parseEther("1000.0"),
      });

      const tknArtifact: Artifact = await artifacts.readArtifact("MockTaxedToken");
      this.mockTaxedToken = <MockTaxedToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          "Dai Stablecoin",
          "DAI",
          this.signers.admin.address,
        ])
      );

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.mockWETH.address]);

      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>await waffle.deployContract(this.signers.admin, liquidatorArtifact);

      const ethArtifact: Artifact = await artifacts.readArtifact("ETHStrategy");
      this.ethStrategy = <ETHStrategy>await waffle.deployContract(this.signers.admin, ethArtifact, [
        "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", // stETH
        "0xF403C135812408BFbE8713b5A23a04b3D48AAE31", // Convex booster
        23, // stETH-ETH Curve pool ID
        this.vault.address,
        this.liquidator.address,
      ]);

      await this.vault.addStrategy(this.ethStrategy.address);
    });

    checkOpenPosition();
    checkClosePosition();
  });
});
