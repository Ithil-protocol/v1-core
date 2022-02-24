import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { Vault } from "../../src/types/Vault";
import { Signers } from "../types";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../src/types/MockWETH";
import { BigNumber } from "ethers";

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

      const tknArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [this.mockKyberNetworkProxy.address])
      );

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.mockWETH.address]);
    });

    checkWhiteList(); // whitelistToken, whitelistTokenAndExec
    // checkStake(); // stake, unstake
    // checkBorrow(); // borrow, repay
  });
});

function checkWhiteList(): void {
  it("check whitelistToken", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH.address;
    const initialState = {
      vaultState: await this.vault.vaults(token),
    };

    await this.vault.whitelistToken(token, baseFee, fixedFee);

    const finalState = {
      vaultState: await this.vault.vaults(token),
    };
    console.log(initialState, finalState);

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });

  it("check whitelistTokenAndExec", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const OUSD = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    let ABI = '[{"inputs": [],"name": "rebaseOptIn","outputs": [],"stateMutability": "nonpayable","type": "function"}]';
    let iface = new ethers.utils.Interface(ABI);
    const data = iface.encodeFunctionData("rebaseOptIn");

    const initialState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    await this.vault.whitelistTokenAndExec(OUSD, baseFee, fixedFee, data);

    const finalState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });
}

function checkStake(): void {
  it("check stake", async function () {
    const amount = ethers.utils.parseUnits("1.0", 18);
    // await this.vault.connect(this.signers.investor).stake(addresses.MockTaxedToken, amount);
  });
  it("check unstake", async function () {});
}

function checkBorrow(): void {
  it("check borrow", async function () {});
  it("check repay", async function () {});
}
