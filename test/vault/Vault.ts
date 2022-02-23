import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { Vault } from "../../src/types/Vault";
import { Signers } from "../types";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
  });

  describe("Vault", function () {
    console.log("hello, here is vault");
    beforeEach(async function () {
      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, greeterArtifact, [greeting]);
    });

    checkBalance();
  });
});

function checkBalance(): void {
  it("should return the new greeting once it's changed", async function () {
    expect(await this.greeter.connect(this.signers.admin).greet()).to.equal("Hello, world!");

    await this.greeter.setGreeting("Bonjour, le monde!");
    expect(await this.greeter.connect(this.signers.admin).greet()).to.equal("Bonjour, le monde!");
  });
}
