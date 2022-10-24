import { network, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";

import type { MockTimeTokenizedVault } from "../../src/types/MockTimeTokenizedVault";
import type { MockToken } from "../../src/types/MockToken";
import { tokenizedVaultFixture, mockTimeTokenizedVaultFixture } from "../common/mockfixtures";
import { verifyStateTokenizedVault } from "../common/utils";

describe("Tokenized Vault state test", function () {
  const createFixtureLoader = waffle.createFixtureLoader;

  type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

  let wallet: Wallet, other: Wallet;

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
    unit = BigNumber.from(10).pow(await native.decimals());
  });

  describe("One-dimensional state modifications", function () {
    it("Boost", async function () {
      const amount = unit;
      const targetState = {
        boostedAmount: amount,
        netLoans: BigNumber.from(0),
        latestRepay: BigNumber.from(0),
        currentProfits: BigNumber.from(0),
        blockTimestamp: BigNumber.from(1601906400),
        balance: BigNumber.from(0),
      };
      await verifyStateTokenizedVault(vault, native, targetState);
    });
  });
});
