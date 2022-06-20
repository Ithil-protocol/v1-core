import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../../types";
import { Artifact } from "hardhat/types";
import { Liquidator } from "../../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../../src/types/MockWETH";
import { Vault } from "../../../../src/types/Vault";
import { TestStrategy } from "../../../../src/types/TestStrategy";
import { Wallet, BigNumber } from "ethers";

import { mockTestFixture } from "../../../common/mockfixtures";
import { MockTaxedToken } from "../../../../src/types/MockTaxedToken";

import { expandToNDecimals, fundVault } from "../../../common/utils";
import { checkSetRiskFactor } from "./TestStrategy.setRiskFactor";
import { checkGetPosition } from "./TestStrategy.getPosition";
import { checkTotalAllowance } from "./TestStrategy.totalAllowance";
import { checkVaultAddress } from "./TestStrategy.vaultAddress";
import { checkOpenPosition } from "./TestStrategy.openPosition";
import { checkClosePosition } from "./TestStrategy.closePosition";
import { checkEditPosition } from "./TestStrategy.editPosition";
import { checkStatus } from "./TestStrategy.status";
import { checkArbitraryBorrow } from "./TestStrategy.arbitraryBorrow";
import { checkArbitraryRepay } from "./TestStrategy.arbitraryRepay";
import { marginTokenMargin, marginTokenLiquidity, leverage } from "../../../common/params";

import { expect } from "chai";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let mockWETH: MockWETH;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof mockTestFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: TestStrategy;
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

let riskFactor = BigNumber.from(100);
let fixedFee = BigNumber.from(10);

describe("Strategy tests", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ mockWETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      mockTestFixture,
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

    // mint tokens to staker
    await marginToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader1).approve(strategy.address, ethers.constants.MaxUint256);

    // mint tokens to trader
    await marginToken.mintTo(trader1.address, expandToNDecimals(10000, 18));

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
  });
  // checkSetRiskFactor();
  // checkGetPosition();
  // checkTotalAllowance();
  // checkVaultAddress();
  // checkOpenPosition();
  // checkClosePosition();
  // checkEditPosition();
  it("TestStrategy: status", async function () {
    const quote = await strategy.quote(mockWETH.address, mockWETH.address, marginTokenMargin);
    expect(quote[0]).to.equal(marginTokenMargin);
    expect(quote[1]).to.equal(marginTokenMargin);

    expect(await strategy.name()).to.equal("TestStrategy");
  });

  it("Arbitrary borrow", async function () {
    await strategy.arbitraryBorrow(marginToken.address, marginTokenMargin, riskFactor, trader1.address);
  });
  it("Arbitrary repay", async function () {
    await strategy.arbitraryBorrow(marginToken.address, marginTokenMargin, riskFactor, trader1.address);
    await strategy.arbitraryRepay(
      marginToken.address,
      marginTokenMargin,
      marginTokenMargin,
      fixedFee,
      riskFactor,
      trader1.address,
    );
  });
});
