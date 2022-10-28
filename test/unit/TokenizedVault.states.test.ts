import { network, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { MockTimeTokenizedVault } from "../../src/types/MockTimeTokenizedVault";
import type { MockToken } from "../../src/types/MockToken";
import { tokenizedVaultFixture, mockTimeTokenizedVaultFixture } from "../common/mockfixtures";
import {
  increaseLatestRepay,
  increaseLoans,
  decreaseLoans,
  increaseBalance,
  increaseCurrentProfits,
  decreaseCurrentProfits,
  verifyStateTokenizedVault,
  advanceTime,
} from "../common/utils";
import exp from "constants";

describe("Tokenized Vault state test", function () {
  const createFixtureLoader = waffle.createFixtureLoader;

  type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

  let wallet: Wallet, other: Wallet;

  let initialTime: BigNumber;
  let native: MockToken;
  let admin: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;
  let createVault: ThenArg<ReturnType<typeof mockTimeTokenizedVaultFixture>>["createVault"];
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  let vault: MockTimeTokenizedVault;
  let unit: BigNumber;
  before("load fixture", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
    ({ native, admin, investor1, investor2, createVault } = await loadFixture(mockTimeTokenizedVaultFixture));
    vault = await createVault();
    initialTime = await vault.time();
  });

  describe("One-dimensional state modifications", function () {
    before("load fixture", async () => {
      [wallet, other] = await (ethers as any).getSigners();
      loadFixture = createFixtureLoader([wallet, other]);
      ({ native, admin, investor1, investor2, createVault } = await loadFixture(mockTimeTokenizedVaultFixture));
      vault = await createVault();
      unit = BigNumber.from(10).pow(await native.decimals());
    });

    describe("Validations", function () {
      it("Increase netLoans", async function () {
        await increaseLoans(vault, native, BigNumber.from(1));
      });

      it("Decrease netLoans", async function () {
        await decreaseLoans(vault, native, BigNumber.from(1));
      });

      it("Increase latestRepay", async function () {
        await increaseLatestRepay(vault, native, BigNumber.from(1));
      });

      it("Increase currentProfits", async function () {
        await increaseCurrentProfits(vault, native, BigNumber.from(1));
      });

      it("Decrease currentProfits (stay positive)", async function () {
        await decreaseCurrentProfits(vault, native, BigNumber.from(1));
      });

      it("Decrease currentProfits (go negative)", async function () {
        await decreaseCurrentProfits(vault, native, (await vault.vaultAccounting()).currentProfits.mul(2));
      });

      it("Advance time", async function () {
        await advanceTime(vault, native, BigNumber.from(1));
      });

      it("Increase balance", async function () {
        await increaseBalance(vault, native, BigNumber.from(1));
      });
    });
  });
});
