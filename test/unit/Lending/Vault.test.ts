import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { Signers } from "../../types";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";

import { checkWhiteList } from "./Vault.whiteList";
import { checkTreasuryStaking } from "./Vault.treasuryStake";
import { checkRebalanceInsurance } from "./Vault.insuranceRebalance";
import { checkClaimable } from "./Vault.claimable";
import { checkStaking } from "./Vault.stake";
import { checkLock } from "./Vault.lock";
import { checkBorrow } from "./Vault.borrow";
import { checkAddStrategy } from "./Vault.addStrategy";

describe("Lending unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];

    this.provider = waffle.provider;

    const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
    this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
      await waffle.deployContract(this.signers.admin, kyberArtifact, [])
    );

    const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
    this.mockWETH = <MockWETH>await waffle.deployContract(this.signers.admin, wethArtifact, []);

    const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
    this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [
      this.mockWETH.address,
      // this.signers.admin.address, // treasury is admin in this case. TODO: implement treasury contract tests
    ]);
  });

  describe("Vault", function () {
    checkWhiteList(); // whitelistToken
    checkStaking(); // stake, unstake
    checkAddStrategy(); // addStrategy, removeStrategy
    // checkTreasuryStaking();
    // checkRebalanceInsurance();
    checkClaimable();
    checkLock();
    // checkBorrow(); // borrow, repay // TODO: currently, skip borrow checking because it is strategyOnly
  });
});
