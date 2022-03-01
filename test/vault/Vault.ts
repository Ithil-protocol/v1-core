import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../src/types/Vault";
import { Signers } from "../types";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../src/types/MockWETH";

import { checkWhiteList } from "./Vault.whiteList";
import { checkStake } from "./Vault.stake";
import { checkBorrow } from "./Vault.borrow";
import { checkAddStrategy } from "./Vault.addStrategy";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("Vault", function () {
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
    });

    checkWhiteList(); // whitelistToken, whitelistTokenAndExec
    checkStake(); // stake, unstake
    checkAddStrategy(); // addStrategy, removeStrategy
    // checkBorrow(); // borrow, repay // TODO: currently, skip borrow checking because it is strategyOnly
  });
});
