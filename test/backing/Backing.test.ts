import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers, waffle } from "hardhat";
import { BigNumber } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import { Backer } from "../../src/types/Backer";
import { MockToken } from "../../src/types/MockToken";

describe("Backer", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployBacker() {
    const [owner, purchaser, redeemer] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockToken");
    const nativeToken = <MockToken>await Token.deploy("Native token", "NAT", 18);
    const stablecoin = <MockToken>await Token.deploy("Stablecoin", "DAI", 18);

    const Backer = await ethers.getContractFactory("Backer");
    const backer = <Backer>await Backer.deploy(stablecoin.address, nativeToken.address);

    return { backer, nativeToken, stablecoin, owner, purchaser, redeemer };
  }

  describe("Deployment", function () {
    let backerContract: Backer;
    let native: MockToken, numeraire: MockToken;
    let admin: SignerWithAddress;
    before("Load fixture", async () => {
      const { backer, nativeToken, stablecoin, owner } = await loadFixture(deployBacker);
      [backerContract, native, numeraire, admin] = [backer, nativeToken, stablecoin, owner];
    });

    it("Should set the right owner", async function () {
      expect(await backerContract.owner()).to.equal(admin.address);
    });

    it("Should set the right native token", async function () {
      expect(await backerContract.native()).to.equal(native.address);
    });

    it("Should set the right numeraire token", async function () {
      expect(await backerContract.numeraire()).to.equal(numeraire.address);
    });

    // it("Other deployments checks", async function () {
    // });
  });

  describe("Functions", function () {
    let backerContract: Backer;
    let native: MockToken, numeraire: MockToken;
    let admin: SignerWithAddress, buyer: SignerWithAddress, seller: SignerWithAddress;
    before("Load fixture", async () => {
      const { backer, nativeToken, stablecoin, owner, purchaser, redeemer } = await loadFixture(deployBacker);
      [backerContract, native, numeraire, admin, buyer, seller] = [
        backer,
        nativeToken,
        stablecoin,
        owner,
        purchaser,
        redeemer,
      ];
    });
    
    describe("Validations", function () {
      it("Non-admin cannot set purchaser", async function () {
        await expect(backerContract.connect(buyer).togglePurchaser(buyer.address)).to.be.reverted;
      });

      it("Cannot purchase more than own purchasable datum", async function () {
        // mint some tokens to buyer
        await numeraire.mintTo(buyer.address, BigNumber.from(1000));

        await expect(backerContract.connect(buyer).purchaseExactNat(1, buyer.address)).to.be.reverted;
      });

      it("Cannot purchase zero amount", async function () {
        // mint some tokens to buyer
        await expect(backerContract.connect(buyer).purchaseExactNat(0, buyer.address)).to.be.reverted;
      });

      it("Cannot purchase more than backer balance", async function () {
        // mint some tokens to buyer
        const purchaseAmount = ethers.utils.parseUnits("1000", 18);
        await numeraire.mintTo(buyer.address, purchaseAmount);

        await backerContract.connect(admin).togglePurchaser(buyer.address);

        await expect(backerContract.connect(buyer).purchaseExactNat(1, buyer.address)).to.be.reverted;
      });

      xit("Cannot redeem if does not have enough native tokens", async function () {});
    });

    describe("Events", function () {
      xit("Event 1", async function () {});
    });

    describe("Actual functions", function () {
      xit("Function 1", async function () {});
    });
  });
});
