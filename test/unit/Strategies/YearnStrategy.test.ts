import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { MockTaxedToken } from "../../../src/types/MockTaxedToken";
import { YearnStrategy } from "../../../src/types/YearnStrategy";
import { Liquidator } from "../../../src/types/Liquidator";

import { expandToNDecimals, fundVault } from "../../common/utils";
import { marginTokenMargin, marginTokenLiquidity, leverage } from "../../common/params";

import { mockYearnFixture } from "../../common/mockfixtures";
import { BigNumber, Wallet } from "ethers";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let mockWETH: MockWETH;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof mockYearnFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: YearnStrategy;
let tokensAmount: BigNumber;
let mockKyberNetworkProxy: MockKyberNetworkProxy;

let marginToken: MockTaxedToken;
let investmentToken: MockTaxedToken;

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

describe("Strategy tests", function () {
  before("create fixture loader", async () => {
    before("create fixture loader", async () => {
      [wallet, other] = await (ethers as any).getSigners();
      loadFixture = createFixtureLoader([wallet, other]);
    });

    before("load fixtures", async () => {
      ({ mockWETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
        mockYearnFixture,
      ));
      strategy = await createStrategy();
    });

    before("prepare vault with default parameters", async () => {
      const signers: SignerWithAddress[] = await ethers.getSigners();
      const staker = signers[1];

      const tokenArtifact: Artifact = await artifacts.readArtifact("MockTaxedToken");
      marginToken = <MockTaxedToken>await waffle.deployContract(admin, tokenArtifact, ["Margin mock token", "MGN", 18]);
      investmentToken = <MockTaxedToken>(
        await waffle.deployContract(admin, tokenArtifact, ["Investment mock token", "INV", 18])
      );

      await vault.whitelistToken(marginToken.address, 10, 10, 1000, expandToNDecimals(1000000, 18));
      await vault.whitelistToken(investmentToken.address, 10, 10, 1, expandToNDecimals(1000, 18));
      await fundVault(staker, vault, marginToken, marginTokenLiquidity);

      await strategy.addYVault(marginToken.address);

      await marginToken.connect(trader1).approve(strategy.address, marginTokenMargin);

      order = {
        spentToken: marginToken.address,
        obtainedToken: investmentToken.address,
        collateral: marginTokenMargin,
        collateralIsSpentToken: true,
        minObtained: BigNumber.from(2).pow(255), // this order is invalid unless we reduce this parameter
        maxSpent: marginTokenMargin.mul(leverage),
        deadline: deadline,
      };
      await strategy.setRiskFactor(marginToken.address, 3000);
      await strategy.setRiskFactor(investmentToken.address, 4000);

      // mint tokens
      await marginToken.mintTo(mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
      await investmentToken.mintTo(mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
    });
  });
});
