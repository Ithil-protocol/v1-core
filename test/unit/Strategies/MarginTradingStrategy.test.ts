import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../src/types/Vault";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { MarginTradingStrategy } from "../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockToken } from "../../../src/types/MockToken";
import { expandToNDecimals, equalWithTolerance } from "../../common/utils";
import { BigNumber, Wallet } from "ethers";
import { marginTokenLiquidity, investmentTokenLiquidity, marginTokenMargin, leverage } from "../../common/params";

import { mockMarginTradingFixture } from "../../common/mockfixtures";
import { fundVault, changeRate } from "../../common/utils";

import { expect } from "chai";
import exp from "constants";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let initialTraderBalance = expandToNDecimals(1000000, 18);

let wallet: Wallet, other: Wallet;

let mockWETH: MockWETH;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let investor1: SignerWithAddress;
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
let positionId = 1;

describe("Margin Trading Strategy unit tests", function () {
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
    investor1 = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("MockToken");
    marginToken = <MockToken>await waffle.deployContract(admin, tokenArtifact, ["Margin mock token", "MGN", 18]);
    investmentToken = <MockToken>(
      await waffle.deployContract(admin, tokenArtifact, ["Investment mock token", "INV", 18])
    );

    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(investmentToken.address, 10, 10, 1);

    // mint margin tokens to staker and fund vault
    await marginToken.mintTo(investor1.address, expandToNDecimals(100000, 18));
    await fundVault(investor1, vault, marginToken, marginTokenLiquidity);

    // mint investment tokens to staker and fund vault
    await investmentToken.mintTo(investor1.address, expandToNDecimals(100000, 18));
    await fundVault(investor1, vault, investmentToken, investmentTokenLiquidity);

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

  it("Open a no-leverage position and set price1, and close immediately", async function () {
    price1 = BigNumber.from(100);
    await mockKyberNetworkProxy.setRate(marginToken.address, 1);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price1);

    const [minObtained] = await strategy.quote(marginToken.address, investmentToken.address, marginTokenMargin);
    order.minObtained = minObtained;
    order.maxSpent = marginTokenMargin;

    const tBalanceBefore = await marginToken.balanceOf(trader1.address);
    await strategy.connect(trader1).openPosition(order);
    const position = await strategy.positions(positionId);
    const [maxOrMin] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);
    await strategy.connect(trader1).closePosition(positionId, maxOrMin);
    positionId++;
    const tBalanceAfter = await marginToken.balanceOf(trader1.address);
  });

  it("Open a sub-1-leverage position and close immediately", async function () {
    price1 = BigNumber.from(100);
    const [minObtained] = await strategy.quote(marginToken.address, investmentToken.address, marginTokenMargin.div(2));
    order.minObtained = minObtained;
    order.maxSpent = marginTokenMargin.div(2);

    await strategy.connect(trader1).openPosition(order);
    const position = await strategy.positions(positionId);
    const [maxOrMin] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);
    await strategy.connect(trader1).closePosition(positionId, maxOrMin);
    positionId++;
  });

  it("Open position with price1", async function () {
    initialTraderBalance = await marginToken.balanceOf(trader1.address);
    vaultMarginBalance = await marginToken.balanceOf(vault.address);
    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    traderBalance = await marginToken.balanceOf(trader1.address);
    expect(traderBalance).to.equal(initialTraderBalance);
    order.maxSpent = marginTokenMargin.mul(leverage);

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

    const position = await strategy.positions(positionId);
    fees = position.fees;
    // Fees should be (maxSpent) * fixedFee / 10000;
    expect(fees).to.equal(order.maxSpent.mul((await vault.vaults(marginToken.address)).fixedFee).div(10000));
    expect(position.allowance).to.equal(minObtained);
    expect(position.principal).to.equal(marginTokenMargin.mul(leverage - 1));
  });

  it("Check optimal ratio increased", async function () {
    const vaultState = await vault.vaults(marginToken.address);
    expect(vaultState.optimalRatio).to.be.above(0);
  });

  it("Raise rate and close position", async function () {
    price2 = BigNumber.from(110);
    await mockKyberNetworkProxy.setRate(investmentToken.address, price2);

    const position = await strategy.positions(positionId);
    const [minObtained] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);

    // Close with 1% allowance
    await strategy.connect(trader1).closePosition(positionId, minObtained.mul(99).div(100));
    positionId++;

    // Compute gain
    const gain = (await marginToken.balanceOf(trader1.address)).sub(initialTraderBalance);
    // Price increased by 10% but trader1 undertook 10x leverage -> should result in a 100% gain minus fees (todo: precise fees calculations)
    expect(gain).to.be.below(marginTokenMargin.sub(fees));
  });

  it("Check vault balance", async function () {
    // Should be equal to the original balance, plus the generated fees (todo: precise fees calculations)
    const newBalance = await marginToken.balanceOf(vault.address);
    expect(newBalance).to.be.above(vaultMarginBalance.add(fees));
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
    initialTraderBalance = await marginToken.balanceOf(trader1.address);
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
    // TODO: corrections due to integer arithmetic errors
    // expect(toBorrow).to.equal((marginTokenMargin.mul(leverage).div(price2)));

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
    const position = await strategy.positions(positionId);
    fees = position.fees;
    // Fees should be principal * fixedFee / 10000;
    const vaultData = await vault.vaults(investmentToken.address);
    expect(fees).to.equal(position.principal.mul(vaultData.fixedFee).div(10000));

    // The allowance is what has been obtained from the swap + the margin posted
    expect(position.allowance).to.equal(expectedObtained.add(marginTokenMargin));
    // The principal is toBorrow
    expect(position.principal).to.equal(toBorrow);
  });

  it("Lower the rate and close position", async function () {
    await changeRate(mockKyberNetworkProxy, investmentToken, 90);

    const position = await strategy.positions(positionId);

    // check how many margin tokens to sell in order to repay the vault
    // principal + fees is not enough due to the time fees: we repay 1% more
    const [maxSpent] = await strategy.quote(
      investmentToken.address,
      marginToken.address,
      position.principal.add(position.fees).mul(101).div(100),
    );
    await strategy.connect(trader1).closePosition(positionId, maxSpent);
    positionId++;

    // trader should have gained
    expect(await marginToken.balanceOf(trader1.address)).to.be.above(initialTraderBalance);
  });

  it("Check vault gained again and has no loans", async function () {
    const newBalance = await investmentToken.balanceOf(vault.address);
    expect(newBalance).to.be.above(vaultInvestmentBalance);
    vaultInvestmentBalance = newBalance;
    const vaultData = await vault.vaults(marginToken.address);
    expect(vaultData.netLoans).to.equal(0);
    expect(vaultData.optimalRatio).to.equal(0);
    expect(vaultData.insuranceReserveBalance).to.equal(0);
  });

  it("Check staker can unstake the unlocked amount", async function () {
    const initialInvestorBalance = await marginToken.balanceOf(investor1.address);
    const vaultData = await vault.vaults(marginToken.address);
    const currentProfits = vaultData.currentProfits;
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    // staker cannot unstake everything now
    await expect(vault.connect(investor1).unstake(marginToken.address, marginTokenLiquidity.add(currentProfits))).to.be
      .reverted;
    // but he can stake just a little bit (TODO: precise unlocked amount)
    await vault.connect(investor1).unstake(marginToken.address, marginTokenLiquidity.add(currentProfits.div(21600)));
    // Six hours pass
    await ethers.provider.send("evm_mine", [timestampBefore + 21600]);
    // now staker can unstake everything missing
    await vault.connect(investor1).unstake(marginToken.address, currentProfits.sub(currentProfits.div(21600)));
    // check investor balance
    equalWithTolerance(
      await marginToken.balanceOf(investor1.address),
      initialInvestorBalance.add(marginTokenLiquidity).add(currentProfits),
      6,
    );
  });
});
