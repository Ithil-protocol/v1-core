import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { MarginTradingStrategy } from "../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockToken } from "../../../src/types/MockToken";
import { expandToNDecimals } from "../../common/utils";
import { BigNumber, Wallet } from "ethers";
import { marginTokenLiquidity, investmentTokenLiquidity, marginTokenMargin, leverage } from "../../common/params";

import { mockMarginTradingFixture } from "../../common/mockfixtures";
import { fundVault, changeRate } from "../../common/utils";

import { expect } from "chai";
import exp from "constants";

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

let marginToken: MockToken;
let investmentToken: MockToken;
let traderBalance: BigNumber;
let vaultMarginBalance: BigNumber;
let vaultInvestmentBalance: BigNumber;
const price1 = BigNumber.from(1);
const price2 = BigNumber.from(100);
let fees: BigNumber;

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

describe("Margin Trading Strategy Liquidation unit tests", function () {
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

    const tokenArtifact: Artifact = await artifacts.readArtifact("MockToken");
    marginToken = <MockToken>await waffle.deployContract(admin, tokenArtifact, ["Margin mock token", "MGN", 18]);
    investmentToken = <MockToken>(
      await waffle.deployContract(admin, tokenArtifact, ["Investment mock token", "INV", 18])
    );

    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(investmentToken.address, 10, 10, 1);

    // mint margin tokens to staker and fund vault
    await marginToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, marginToken, marginTokenLiquidity);

    // mint investment tokens to staker and fund vault
    await investmentToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, investmentToken, investmentTokenLiquidity);

    vaultMarginBalance = await marginToken.balanceOf(vault.address);

    // Trader starts with initialTraderBalance tokens
    await marginToken.mintTo(trader1.address, initialTraderBalance);
    await marginToken.connect(trader1).approve(strategy.address, initialTraderBalance);

    // Mint tokens to the liquidator so that it can make margin calls and purchase assets
    await marginToken.mintTo(liquidator.address, initialTraderBalance);
    await marginToken.connect(liquidator).approve(strategy.address, initialTraderBalance);
    await marginToken.connect(liquidator).approve(liquidatorContract.address, initialTraderBalance);
    await investmentToken.mintTo(liquidator.address, initialTraderBalance);
    await investmentToken.connect(liquidator).approve(strategy.address, initialTraderBalance);
    await investmentToken.connect(liquidator).approve(liquidatorContract.address, initialTraderBalance);

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

  it("Check forced closure on a long position", async function () {
    // Initial price ratio is 1:100
    await mockKyberNetworkProxy.setRate(marginToken.address, price1);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    // calculate minimum obtained and open position (0% slippage since we are mock)
    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );
    order.minObtained = minObtained;

    // open position
    await strategy.connect(trader1).openPosition(order);

    // check liquidation score math
    let position = await strategy.positions(1);
    const [liquidationScore, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    const profitAndLoss = (await strategy.quote(investmentToken.address, marginToken.address, position.allowance))[0]
      .sub(position.principal)
      .sub(dueFees);

    // liquidation score = collateral * risk factor - P&L * 10000
    const liquidationScoreComputed = position.collateral.mul(pairRiskFactor).sub(profitAndLoss.mul(10000));
    expect(liquidationScore).to.equal(liquidationScoreComputed);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 1)).to.be.reverted;

    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must drop by (10000 - riskFactor)/leverage
    const priceDrop = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).sub(priceDrop)).div(10000);

    // Liquidation should fail again for higher price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    await expect(liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 1)).to.be.reverted;

    // But it should occur for newPrice
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice);
    const [, newDueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 1);
    position = await strategy.positions(1);
    expect(position.principal).to.equal(0);

    // Trader lost everything
    expect(await marginToken.balanceOf(trader1.address)).to.equal(initialTraderBalance.sub(marginTokenMargin));
    // Vault should gain the due fees + missed liquidator reward (precise calculations in another test)
    expect(await marginToken.balanceOf(vault.address)).to.be.above(vaultMarginBalance.add(newDueFees));
  });

  it("Check forced closure on a short position", async function () {
    // Reset rates: 1:100
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    order.deadline = deadline;
    order.spentToken = investmentToken.address;
    order.obtainedToken = marginToken.address;
    order.collateralIsSpentToken = false;

    // save vault balance since we will need to measure gain later
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);

    // check how many investments token margin * leverage margin tokens are worth
    const [toBorrow] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    // We expect that margin * leverage margin tokens are worth margin * leverage / price2 investment tokens
    // Numbers: margin = 10**20, price = 100, leverage = 10 -> toBorrow = 10**19
    expect(toBorrow).to.equal(marginTokenMargin.mul(leverage).div(price2));

    order.minObtained = marginTokenMargin.mul(leverage);
    order.maxSpent = toBorrow;
    traderBalance = await marginToken.balanceOf(trader1.address);

    await strategy.connect(trader1).openPosition(order);
    // Now the strategy should have margin * (leverage + 1) margin tokens
    expect(await marginToken.balanceOf(strategy.address)).to.equal(marginTokenMargin.mul(leverage + 1));

    // check liquidation score math
    let position = await strategy.positions(2);
    const [liquidationScore, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);

    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    const profitAndLoss = position.allowance.sub(
      (await strategy.quote(investmentToken.address, marginToken.address, position.principal.add(dueFees)))[0],
    );
    // liquidation score = collateral * risk factor - P&L * 10000
    const liquidationScoreComputed = position.collateral.mul(pairRiskFactor).sub(profitAndLoss.mul(10000));
    expect(liquidationScore).to.equal(liquidationScoreComputed);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2)).to.be.reverted;
    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must raise by (10000 - riskFactor)/leverage
    const priceRaise = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).add(priceRaise)).div(10000);

    // Liquidation should fail again for lower price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.sub(1));
    await expect(liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2)).to.be.reverted;

    // But it should occur for newPrice + 1 (modulo approximation errors)
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    const [, newDueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 2);
    position = await strategy.positions(2);
    expect(position.principal).to.equal(0);

    // Trader lost everything
    expect(await marginToken.balanceOf(trader1.address)).to.equal(traderBalance.sub(marginTokenMargin));
    // Vault should gain the due fees + missed liquidator reward (precise calculations in another test)
    expect(await investmentToken.balanceOf(vault.address)).to.be.above(vaultInvestmentBalance.add(newDueFees));
  });

  it("Check margin call on a long position", async function () {
    // Initial price ratio is 1:100
    await mockKyberNetworkProxy.setRate(marginToken.address, price1);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    // reset long order
    order.deadline = deadline;
    order.spentToken = marginToken.address;
    order.obtainedToken = investmentToken.address;
    order.maxSpent = marginTokenMargin.mul(leverage);
    order.collateralIsSpentToken = true;

    // at this point the strategy should have no asset
    expect(await marginToken.balanceOf(strategy.address)).to.equal(0);
    expect(await investmentToken.balanceOf(strategy.address)).to.equal(0);

    // calculate minimum obtained and open position (0% slippage since we are mock)
    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );
    order.minObtained = minObtained;

    // open position
    await strategy.connect(trader1).openPosition(order);
    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    const extraMargin = expandToNDecimals(50, 18);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).marginCall(strategy.address, 3, extraMargin)).to.be.reverted;

    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must drop by (10000 - riskFactor)/leverage
    const priceDrop = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).sub(priceDrop)).div(10000);

    // Liquidation should fail again for higher price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    await expect(liquidatorContract.connect(liquidator).marginCall(strategy.address, 3, extraMargin)).to.be.reverted;

    // But it should occur for newPrice
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice);
    await liquidatorContract.connect(liquidator).marginCall(strategy.address, 3, extraMargin);

    const position = await strategy.positions(3);
    const maxSpent = position.allowance;

    expect(await strategy.ownerOf(3)).to.be.equal(liquidator.address);

    // The position is not closed, but it changed ownership
    await expect(strategy.connect(trader1).closePosition(3, maxSpent)).to.be.reverted;
    await strategy.connect(liquidator).closePosition(3, maxSpent);
    expect((await strategy.positions(3)).principal).to.equal(0);
  });

  it("Check margin call on a short position", async function () {
    // Reset rates: 1:100
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    order.deadline = deadline;
    order.spentToken = investmentToken.address;
    order.obtainedToken = marginToken.address;
    order.collateralIsSpentToken = false;

    // save vault balance since we will need to measure gain later
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);

    // check how many investments token margin * leverage margin tokens are worth
    const [toBorrow] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = marginTokenMargin.mul(leverage);
    order.maxSpent = toBorrow;
    traderBalance = await marginToken.balanceOf(trader1.address);
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);

    await strategy.connect(trader1).openPosition(order);

    // check liquidation score math
    const position = await strategy.positions(4);
    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    const extraMargin = expandToNDecimals(50, 18);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).marginCall(strategy.address, 4, extraMargin)).to.be.reverted;

    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must raise by (10000 - riskFactor)/leverage
    const priceRaise = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).add(priceRaise)).div(10000);

    // Liquidation should fail again for lower price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.sub(1));
    await expect(liquidatorContract.connect(liquidator).marginCall(strategy.address, 4, extraMargin)).to.be.reverted;

    // But it should occur for newPrice + 1 (modulo approximation errors)
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    await liquidatorContract.connect(liquidator).marginCall(strategy.address, 4, extraMargin);

    // check how many margin tokens to sell in order to repay the vault
    // principal + fees is not enough due to the time fees: we repay 1% more
    const [maxSpent] = await strategy.quote(
      investmentToken.address,
      marginToken.address,
      position.principal.add(position.fees).mul(101).div(100),
    );
    // The position is not closed, but it changed ownership
    await expect(strategy.connect(trader1).closePosition(4, maxSpent)).to.be.reverted;
    await strategy.connect(liquidator).closePosition(4, maxSpent);
    expect((await strategy.positions(4)).principal).to.equal(0);
  });

  it("Check purchase assets on a long position", async function () {
    // Initial price ratio is 1:100
    await mockKyberNetworkProxy.setRate(marginToken.address, price1);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    // reset long order
    order.deadline = deadline;
    order.spentToken = marginToken.address;
    order.obtainedToken = investmentToken.address;
    order.maxSpent = marginTokenMargin.mul(leverage);
    order.collateralIsSpentToken = true;

    // calculate minimum obtained and open position (0% slippage since we are mock)
    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );
    order.minObtained = minObtained;

    const vaultMarginBalance = await marginToken.balanceOf(vault.address);
    const traderBalance = await marginToken.balanceOf(trader1.address);
    const liquidatorBalance = await investmentToken.balanceOf(liquidator.address);
    // open position
    await strategy.connect(trader1).openPosition(order);
    let position = await strategy.positions(5);
    const initialAllowance = position.allowance;
    const [liquidationScore, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    let [fairPrice] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);
    let price = fairPrice.add(dueFees);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 5, price)).to.be.reverted;

    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must drop by (10000 - riskFactor)/leverage
    const priceDrop = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).sub(priceDrop)).div(10000);

    // Liquidation should fail again for higher price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    await expect(liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 5, price)).to.be.reverted;

    // But it should occur for newPrice
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice);
    const [, newDueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    [fairPrice] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);

    // Allow for 1% slippage
    price = fairPrice.add(dueFees).mul(101).div(100);
    await liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 5, price);
    position = await strategy.positions(5);
    expect(position.principal).to.equal(0);

    // The vault gained
    expect(await marginToken.balanceOf(vault.address)).to.be.above(vaultMarginBalance.add(newDueFees));
    // The trader lost
    expect(await marginToken.balanceOf(trader1.address)).to.equal(traderBalance.sub(marginTokenMargin));
    // The liquidator got the position's allowance
    expect(await investmentToken.balanceOf(liquidator.address)).to.equal(liquidatorBalance.add(initialAllowance));
  });

  it("Check purchase assets on a short position", async function () {
    // Reset rates: 1:100
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    order.deadline = deadline;
    order.spentToken = investmentToken.address;
    order.obtainedToken = marginToken.address;
    order.collateralIsSpentToken = false;

    // save vault balance since we will need to measure gain later
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);

    // check how many investments token margin * leverage margin tokens are worth
    const [toBorrow] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = marginTokenMargin.mul(leverage);
    order.maxSpent = toBorrow;
    traderBalance = await marginToken.balanceOf(trader1.address);
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);
    const liquidatorBalance = await marginToken.balanceOf(liquidator.address);

    await strategy.connect(trader1).openPosition(order);

    // check liquidation score math
    const position = await strategy.positions(6);
    const initialAllowance = position.allowance;
    const [liquidationScore, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);
    const pairRiskFactor = await strategy.computePairRiskFactor(investmentToken.address, marginToken.address);
    let [fairPrice] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);
    // some "slippage" is needed liquidator side because the dueFees are increased in the meantime
    let priceToPurchase = fairPrice.add(dueFees);

    // immediate liquidation should fail
    await expect(liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 6, priceToPurchase)).to.be
      .reverted;

    // liquidation should happen at P&L = collateral * riskFactor / 10000
    // thus the price must raise by (10000 - riskFactor)/leverage
    const priceRaise = BigNumber.from(10000).sub(pairRiskFactor).div(leverage);
    const newPrice = BigNumber.from(100).mul(BigNumber.from(10000).add(priceRaise)).div(10000);

    // Liquidation should fail again for lower price
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.sub(1));
    await expect(liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 6, priceToPurchase)).to.be
      .reverted;

    // But it should occur for newPrice + 1 (modulo approximation errors)
    await mockKyberNetworkProxy.setRate(investmentToken.address, newPrice.add(1));
    const [, newDueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, position);

    // precise time fees are difficult to predict: we allow for 0.1% slippage to be sure to repay the vault and not make the call be reverted
    [fairPrice] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);
    // some "slippage" is needed liquidator side because the dueFees are increased in the meantime
    priceToPurchase = fairPrice.add(newDueFees).mul(101).div(100);
    await liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 6, priceToPurchase);

    // The vault gained
    expect(await investmentToken.balanceOf(vault.address)).to.be.above(vaultInvestmentBalance.add(newDueFees));
    // The trader lost
    expect(await marginToken.balanceOf(trader1.address)).to.equal(traderBalance.sub(marginTokenMargin));
    // The liquidator got the position's allowance
    expect(await marginToken.balanceOf(liquidator.address)).to.equal(liquidatorBalance.add(initialAllowance));
  });
});
