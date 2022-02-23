import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { addresses } from "../../deployments/addresses.json";

import type { Vault } from "../../src/types/Vault";
import { Signers } from "../types";

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
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [addresses.MockWETH]);
    });

    checkBalance();
  });
});

function checkBalance(): void {
  it("check states", async function () {
    const token = addresses.MockTaxedToken;
    const initialState = {
      vaultState: await this.vault.vaults(token),
    };
    await this.vault.whitelistToken(token, 10, 10);
    const finalState = {
      vaultState: await this.vault.vaults(token),
    };
    console.log(initialState, finalState);

    // expect(await this.greeter.connect(this.signers.admin).greet()).to.equal("Bonjour, le monde!");
  });
}
