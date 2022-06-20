import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { MockKyberNetworkProxy } from "../../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../../src/types/MockWETH";
import { MarginTradingStrategy } from "../../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";
import { MockTaxedToken } from "../../../../src/types/MockTaxedToken";
import { expandToNDecimals } from "../../../common/utils";
import { BigNumber, Wallet } from "ethers";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";

import { mockMarginTradingFixture } from "../../../common/mockfixtures";
import { fundVault, changeRate } from "../../../common/utils";

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
let createStrategy: ThenArg<ReturnType<typeof mockMarginTradingFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: MarginTradingStrategy;
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
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({
      mockWETH,
      admin,
      trader1,
      trader2,
      liquidator,
      vault,
      liquidatorContract,
      mockKyberNetworkProxy,
      createStrategy,
    } = await loadFixture(mockMarginTradingFixture));
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

    // mint tokens
    await marginToken.mintTo(mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
    await investmentToken.mintTo(mockKyberNetworkProxy.address, ethers.constants.MaxInt256);
  });

  it("MarginTradingStrategy: setRiskFactor", async function () {
    const riskFactor = 200;
    const token = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";

    await strategy.setRiskFactor(token, riskFactor);

    const finalState = {
      riskFactor: await strategy.riskFactors(token),
    };

    expect(finalState.riskFactor).to.equal(BigNumber.from(riskFactor));
  });

  it("MarginTradingStrategy: computePairRiskFactor", async function () {
    const riskFactor0 = 200;
    const riskFactor1 = 300;
    const token0 = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    const token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    await strategy.setRiskFactor(token0, riskFactor0);
    await strategy.setRiskFactor(token1, riskFactor1);

    // expect(finalState.pairRiskFactor).to.equal(BigNumber.from(riskFactor0).add(BigNumber.from(riskFactor1)).div(2));
  });
  it("MarginTradingStrategy: openPosition", async function () {
    await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);

    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    await strategy.connect(trader1).openPosition(order);
  });

  it("MarginTradingStrategy: closePosition", async function () {
    await changeRate(mockKyberNetworkProxy, investmentToken, 11 * 10 ** 10);

    const position = await strategy.positions(1);
    const maxSpent = position.allowance;

    await strategy.connect(trader1).closePosition(1, maxSpent);
  });
  // checkEditPosition(); // TODO: not completed

  it("MarginTradingStrategy: check deadline", async function () {
    order.deadline = 0;
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;
  });

  it("MarginTradingStrategy: check liquidate", async function () {
    order.deadline = deadline;
    // step 1. open position
    await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);

    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    await strategy.connect(trader1).openPosition(order);

    let position0 = await strategy.positions(2);
    // step 2. try to liquidate
    await changeRate(mockKyberNetworkProxy, investmentToken, 98 * 10 ** 9);
    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2);
    let position1 = await strategy.positions(2);
    expect(position1.principal).to.equal(position0.principal);

    // step 3. liquidate
    await changeRate(mockKyberNetworkProxy, investmentToken, 93 * 10 ** 9);
    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2);

    let position2 = await strategy.positions(2);
    expect(position2.principal).to.equal(0);
  });
});
