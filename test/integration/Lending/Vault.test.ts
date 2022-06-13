import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, BigNumberish, constants, Wallet } from "ethers";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";

import { tokens } from "../../common/mainnet";
import { getTokens } from "../../common/utils";

import type { ERC20 } from "../../../src/types/ERC20";
import type { Vault } from "../../../src/types/Vault";

import { checkWhitelist, checkStaking } from "./Vault";

import { vaultFixture } from "../../common/fixtures";
import { Sign } from "crypto";

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

describe("Lending integration tests", function () {
  let wallet: Wallet, other: Wallet;

  let WETH: ERC20;
  let admin: SignerWithAddress;
  let investor: SignerWithAddress;
  let trader: SignerWithAddress;

  let vault: Vault;

  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  let loadFixture: ReturnType<typeof createFixtureLoader>;
  let createVault: ThenArg<ReturnType<typeof vaultFixture>>["createVault"];

  before("create fixture loader", async () => {
    console.log("Getting signers");
    [wallet, other] = await (ethers as any).getSigners();
    console.log("createFixtureLoader");
    loadFixture = createFixtureLoader([wallet, other]);

    console.log("loadFixture");
    ({ WETH, admin, investor, trader, createVault } = await loadFixture(vaultFixture));
    console.log("createVault");
    vault = await createVault();
  });

  describe("Lending", function () {
    checkWhitelist(vault);
    checkStaking(vault, WETH);
  });
});
