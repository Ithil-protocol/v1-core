import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";
import { Artifact } from "hardhat/types";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { Vault } from "../../../src/types/Vault";
import { SyntheticStrategy } from "../../../src/types/SyntheticStrategy";

import { checkOpenPosition } from "./SyntheticStrategy.openPosition";
import { checkClosePosition } from "./SyntheticStrategy.closePosition";
import { checkQuote } from "./SyntheticStrategy.quote";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("SyntheticStrategy", function () {
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

      const ssArtifact: Artifact = await artifacts.readArtifact("SyntheticStrategy");
      this.syntheticStrategy = <SyntheticStrategy>(
        await waffle.deployContract(this.signers.admin, ssArtifact, [this.vault.address, this.liquidator.address])
      );
      await this.vault.addStrategy(this.syntheticStrategy.address);
    });

    checkOpenPosition();
    checkClosePosition();
    checkQuote();
  });
});
