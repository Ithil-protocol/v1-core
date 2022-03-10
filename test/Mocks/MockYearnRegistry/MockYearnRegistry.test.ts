import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";

import { checkLatestVault } from "./MockYearnRegistry.latestVault";
import { checkNewVault } from "./MockYearnRegistry.newVault";
import { checkSetSharePrice } from "./MockYearnRegistry.setSharePrice";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  // TODO: currently, I can't deploy MockYearnRegistry
  describe("MockYearnRegistry", function () {
    beforeEach(async function () {});

    // checkLatestVault();
    // checkNewVault();
    // checkSetSharePrice();
  });
});
