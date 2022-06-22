import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { MarginTradingStrategy } from "../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockTaxedToken } from "../../../src/types/MockTaxedToken";
import { expandToNDecimals } from "../../common/utils";
import { BigNumber, Wallet } from "ethers";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../common/params";

import { mockMarginTradingFixture } from "../../common/mockfixtures";
import { fundVault, changeRate } from "../../common/utils";

import { expect } from "chai";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

const initialTraderBalance = expandToNDecimals(1000000, 18);

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
let traderBalance: BigNumber;
let vaultBalance: BigNumber;

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

    // mint tokens to staker and fund vault
    await marginToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, marginToken, marginTokenLiquidity);

    vaultBalance = await marginToken.balanceOf(vault.address);

    // Trader starts with initialTraderBalance tokens
    await marginToken.mintTo(trader1.address, initialTraderBalance);
    await marginToken.connect(trader1).approve(strategy.address, initialTraderBalance);

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

  it("Set risk factor", async function () {
    const riskFactor = 200;

    await strategy.setRiskFactor(marginToken.address, riskFactor);

    const finalState = {
      riskFactor: await strategy.riskFactors(marginToken.address),
    };

    expect(finalState.riskFactor).to.equal(BigNumber.from(riskFactor));
  });

  it("Set rate and quote", async function () {
    await mockKyberNetworkProxy.setRate(marginToken.address, BigNumber.from(5000));
    await mockKyberNetworkProxy.setRate(investmentToken.address, BigNumber.from(15000));
    let [quoted] = await strategy.quote(marginToken.address, investmentToken.address, 9); // 5000 * 9 / 15000 = 3
    expect(quoted).to.equal(3);
    [quoted] = await strategy.quote(investmentToken.address, marginToken.address, 7); // 15000 * 7 / 5000 = 21
    expect(quoted).to.equal(21);
  });

  it("Open position with a price ratio of 1:10", async function () {
    await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);

    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    traderBalance = await marginToken.balanceOf(trader1.address);
    expect(traderBalance).to.equal(initialTraderBalance);

    await strategy.connect(trader1).openPosition(order);
    expect(await marginToken.balanceOf(trader1.address)).to.equal(initialTraderBalance.sub(marginTokenMargin));
    const position = await strategy.positions(1);
    expect(position.allowance).to.equal(minObtained);
    expect(position.principal).to.equal(marginTokenMargin.mul(leverage - 1));
    expect(position.interestRate).to.equal(0);
  });

  it("Check optimal ratio increased", async function () {
    const vaultState = await vault.vaults(marginToken.address);
    expect(vaultState.optimalRatio).to.be.above(0);
  });

  it("Raise rate and close position", async function () {
    await changeRate(mockKyberNetworkProxy, investmentToken, 11 * 10 ** 10);

    const position = await strategy.positions(1);
    const maxSpent = position.allowance;

    await strategy.connect(trader1).closePosition(1, maxSpent);
    expect(await marginToken.balanceOf(trader1.address)).to.be.above(initialTraderBalance);
  });

  it("Check vault balance", async function () {
    expect(await marginToken.balanceOf(vault.address)).to.be.above(vaultBalance);
  });

  // Both insurance reserve and optimal ratio should be zero now: all the loans have been repaid
  it("Check optimal ratio and insurance reserve", async function () {
    const vaultState = await vault.vaults(marginToken.address);
    expect(vaultState.optimalRatio).to.equal(0);
    expect(vaultState.insuranceReserveBalance).to.equal(0);
  });

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
    await changeRate(mockKyberNetworkProxy, investmentToken, 92 * 10 ** 9);
    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2);

    let position2 = await strategy.positions(2);
    expect(position2.principal).to.equal(0);
  });
});
