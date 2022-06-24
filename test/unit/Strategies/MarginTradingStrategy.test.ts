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

let marginToken: MockTaxedToken;
let investmentToken: MockTaxedToken;
let traderBalance: BigNumber;
let vaultMarginBalance: BigNumber;
let vaultInvestmentBalance: BigNumber;
let price1: BigNumber;
let price2: BigNumber;
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

let position: [string, string, string, string, BigNumber, BigNumber, BigNumber, BigNumber, BigNumber, BigNumber];

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

  it("Open position with price1", async function () {
    price1 = BigNumber.from(100);
    await mockKyberNetworkProxy.setRate(marginToken.address, 1);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price1);

    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    traderBalance = await marginToken.balanceOf(trader1.address);
    expect(traderBalance).to.equal(initialTraderBalance);
    vaultMarginBalance;

    await strategy.connect(trader1).openPosition(order);

    // Check all tokens flows
    // Trader has paid margin
    expect(await marginToken.balanceOf(trader1.address)).to.equal(initialTraderBalance.sub(marginTokenMargin));

    // Vault has borrowed margin * (leverage - 1) tokens for the investment
    const newVaultBalance = await marginToken.balanceOf(vault.address);
    expect(newVaultBalance).to.equal(vaultMarginBalance.sub(marginTokenMargin.mul(leverage - 1)));

    // Strategy has obtained minObtained investment tokens
    expect(await investmentToken.balanceOf(strategy.address)).to.equal(minObtained);

    // Check onchain position data

    const position = await strategy.positions(1);
    fees = position.fees;
    // Fees should be principal * fixedFee / 10000;
    expect(fees).to.equal(position.principal.mul((await vault.vaults(marginToken.address)).fixedFee).div(10000));
    expect(position.allowance).to.equal(minObtained);
    expect(position.principal).to.equal(marginTokenMargin.mul(leverage - 1));
    // no previous risk (first position open: interest rate is zero)
    expect(position.interestRate).to.equal(0);
  });

  it("Check optimal ratio increased", async function () {
    const vaultState = await vault.vaults(marginToken.address);
    expect(vaultState.optimalRatio).to.be.above(0);
  });

  it("Raise rate and close position", async function () {
    price2 = BigNumber.from(110);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    const position = await strategy.positions(1);
    const maxSpent = position.allowance;

    await strategy.connect(trader1).closePosition(1, maxSpent);

    // Compute gain
    const gain = (await marginToken.balanceOf(trader1.address)).sub(initialTraderBalance);
    // Price increased by 10% but trader1 undertook 10x leverage -> should result in a 100% gain minus fees
    expect(gain).to.equal(marginTokenMargin.sub(fees));
  });

  it("Check vault balance", async function () {
    // Should be equal to the original balance, plus the generated fees
    const newBalance = await marginToken.balanceOf(vault.address);
    expect(newBalance).to.equal(vaultMarginBalance.add(fees));
    vaultMarginBalance = newBalance;
  });

  // Both insurance reserve and optimal ratio should be zero now: all the loans have been repaid
  it("Check optimal ratio and insurance reserve", async function () {
    const vaultState = await vault.vaults(marginToken.address);
    expect(vaultState.optimalRatio).to.equal(0);
    expect(vaultState.insuranceReserveBalance).to.equal(0);
  });

  it("Revert if deadline is expired", async function () {
    order.deadline = 0;
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;
  });

  it("Open the position in the opposite side", async function () {
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
    expect(toBorrow).to.equal(marginTokenMargin.mul(leverage).div(price2));

    order.maxSpent = toBorrow;
    traderBalance = await marginToken.balanceOf(trader1.address);
    vaultInvestmentBalance = await investmentToken.balanceOf(vault.address);
    const strategyBalance = await marginToken.balanceOf(strategy.address);

    await strategy.connect(trader1).openPosition(order);

    // Check all token flows
    // Trader has paid margin
    expect(await marginToken.balanceOf(trader1.address)).to.equal(traderBalance.sub(marginTokenMargin));

    // Vault has borrowed toBorrow tokens for the investment
    expect(await investmentToken.balanceOf(vault.address)).to.equal(vaultInvestmentBalance.sub(toBorrow));

    // Strategy has obtained margin * leverage margin tokens, plus the margin already posted
    // Actually not precisely margin * leverage, but the following line, due to approximation errors (only true in mocks):
    const expectedObtained = toBorrow.mul(price2);
    expect(await marginToken.balanceOf(strategy.address)).to.equal(
      strategyBalance.add(expectedObtained).add(marginTokenMargin),
    );

    // Check onchain position data
    const position = await strategy.positions(2);
    fees = position.fees;
    // Fees should be principal * fixedFee / 10000;
    const vaultData = await vault.vaults(investmentToken.address);
    expect(fees).to.equal(position.principal.mul(vaultData.fixedFee).div(10000));

    // The allowance is what has been obtained from the swap + the margin posted
    expect(position.allowance).to.equal(expectedObtained.add(marginTokenMargin));
    // The principal is toBorrow
    expect(position.principal).to.equal(toBorrow);
    // Short position do not have risk discount: interest is baseFee * leverage
    expect(position.interestRate).to.equal(vaultData.baseFee.mul(leverage));
  });

  it("Lower the rate and close position", async function () {
    await changeRate(mockKyberNetworkProxy, investmentToken, 90);

    const position = await strategy.positions(2);

    // check how many margin tokens to sell in order to repay the vault
    const [maxSpent] = await strategy.quote(investmentToken.address, marginToken.address, position.principal);
    console.log("Max spent", ethers.utils.formatUnits(maxSpent, 18));
    await strategy.connect(trader1).closePosition(2, maxSpent);

    // trader should have gained
    expect(await marginToken.balanceOf(trader1.address)).to.be.above(initialTraderBalance);
  });

  // TODO: seems fees behave unexpectedly when position is short

  // it("Check vault gained again and has no loans", async function () {
  //   const newBalance = await investmentToken.balanceOf(vault.address);
  //   expect(newBalance).to.be.above(vaultInvestmentBalance);
  //   vaultInvestmentBalance = newBalance;
  //   const vaultData = await vault.vaults(marginToken.address);
  //   expect(vaultData.netLoans).to.equal(0);
  //   expect(vaultData.optimalRatio).to.equal(0);
  //   expect(vaultData.insuranceReserveBalance).to.equal(0);
  // })

  // TODO: liquidation to be tested further

  // it("Check liquidate", async function () {
  //   // Initial price ratio is 1:100
  //   await changeRate(mockKyberNetworkProxy, marginToken, 1);
  //   await changeRate(mockKyberNetworkProxy, investmentToken, 100);

  //   // Restore long order
  //   order.spentToken = marginToken.address;
  //   order.obtainedToken = investmentToken.address;
  //   order.collateralIsSpentToken = true;

  //   // calculate minimum obtained and open position (0% slippage since we are mock)
  //   const [minObtained] = await strategy.quote(
  //     marginToken.address,
  //     investmentToken.address,
  //     marginTokenMargin.mul(leverage),
  //   );
  //   order.minObtained = minObtained;
  //   await strategy.connect(trader1).openPosition(order);

  //   // try to immediately liquidate
  //   await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 3);
  // })

  // it("Check liquidate", async function () {
  //   // step 1. open position
  //   await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
  //   await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);

  //   const [minObtained] = await strategy.quote(
  //     marginToken.address,
  //     investmentToken.address,
  //     marginTokenMargin.mul(leverage),
  //   );

  //   order.minObtained = minObtained;

  //   await strategy.connect(trader1).openPosition(order);

  //   let position0 = await strategy.positions(3);
  //   // step 2. try to liquidate
  //   await changeRate(mockKyberNetworkProxy, investmentToken, 98 * 10 ** 9);
  //   await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 3);
  //   let position1 = await strategy.positions(3);
  //   expect(position1.principal).to.equal(position0.principal);

  //   // step 3. liquidate
  //   await changeRate(mockKyberNetworkProxy, investmentToken, 85 * 10 ** 9);
  //   await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 3);

  //   let position2 = await strategy.positions(3);
  //   expect(position2.principal).to.equal(0);
  // });
});
