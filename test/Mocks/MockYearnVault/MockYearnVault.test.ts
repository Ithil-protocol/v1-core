import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";

import { checkDeposit } from "./MockYearnVault.deposit";
import { checkWithdraw } from "./MockYearnVault.withdraw";
import { checkPricePerShare } from "./MockYearnVault.pricePerShare";
import { Artifact } from "hardhat/types";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { MockYearnVault } from "../../../src/types/MockYearnVault";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("MockYearnVault", function () {
    beforeEach(async function () {
      const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
        await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      );

      const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>(
        await waffle.deployContract(this.signers.admin, wethArtifact, [this.mockKyberNetworkProxy.address])
      );

      const mockYearnVaultArtifact: Artifact = await artifacts.readArtifact("MockYearnVault");
      this.mockYearnVault = <MockYearnVault>(
        await waffle.deployContract(this.signers.admin, wethArtifact, [this.mockWETH.address])
      );
    });

    // checkDeposit();
    // checkWithdraw();
    // checkPricePerShare();
  });
});
