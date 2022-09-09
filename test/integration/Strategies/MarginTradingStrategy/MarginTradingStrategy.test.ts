import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber, Wallet } from "ethers";

import { tokens } from "../../../common/mainnet";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";
import { marginTokenLiquidity, investmentTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";
import { marginTradingFixture } from "./fixture";

import type { ERC20 } from "../../../../src/types/ERC20";
import type { Vault } from "../../../../src/types/Vault";
import { MarginTradingStrategy } from "../../../../src/types/MarginTradingStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";
import { expect } from "chai";
import exp from "constants";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let WETH: ERC20;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof marginTradingFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: MarginTradingStrategy;
let tokensAmount: BigNumber;
let vaultBalance: BigNumber;

let marginToken: ERC20;
let investmentToken: ERC20;

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

let price: BigNumber;
let quoted: BigNumber;
let openingPrice: BigNumber;

describe("MarginTradingStrategy integration test", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ WETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      marginTradingFixture,
    ));
    strategy = await createStrategy();
  });

  before("prepare vault with default parameters", async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const staker = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    marginToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    investmentToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(investmentToken.address, 10, 10, 1);

    await strategy.setRiskFactor(marginToken.address, 3000);
    await strategy.setRiskFactor(investmentToken.address, 4000);

    await getTokens(staker.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(staker.address, investmentToken.address, tokens.WETH.whale, marginTokenLiquidity);
    await getTokens(trader1.address, marginToken.address, tokens.DAI.whale, investmentTokenLiquidity);
    await fundVault(signers[1], vault, marginToken, marginTokenLiquidity);
    await fundVault(signers[1], vault, investmentToken, investmentTokenLiquidity);

    await marginToken.connect(trader1).approve(strategy.address, BigNumber.from(2).pow(255));

    order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255), // this order is invalid unless we reduce this parameter
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
  });

  it("Check quoter linearly scales", async function () {
    [openingPrice] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );
    const [otherPrice] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage).mul(10),
    );
    // Give 1% tolerance
    expect(otherPrice).to.be.above(openingPrice.mul(10).mul(99).div(100));
    expect(otherPrice).to.be.below(openingPrice.mul(10).mul(101).div(100));
  });

  it("MarginTradingStrategy: too high minObtained should revert", async function () {
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;
  });

  it("MarginTradingStrategy: swap DAI for WETH", async function () {
    vaultBalance = await marginToken.balanceOf(vault.address);
    // 1% slippage
    order.minObtained = openingPrice.mul(99).div(100);
    await strategy.connect(trader1).openPosition(order);

    expect((await strategy.positions(1)).allowance).to.be.above(order.minObtained);
  });

  it("Price did not change much (within 1%)", async function () {
    [price] = await strategy.quote(marginToken.address, investmentToken.address, marginTokenMargin.mul(leverage));
    expect(price).to.be.below(openingPrice.mul(101).div(100));
    expect(price).to.be.above(openingPrice.mul(99).div(100));
  });

  it("Too high min obtained should revert", async function () {
    const allowance = (await strategy.positions(1)).allowance;
    [quoted] = await strategy.quote(investmentToken.address, marginToken.address, allowance);
    // Try to obtain much more than the quoted amount
    const minObtained = quoted.mul(11).div(10);
    await expect(strategy.connect(trader1).closePosition(1, minObtained)).to.be.reverted;
  });

  it("Decent slippage should close successfully", async function () {
    const positionID = 1;

    // 1% slippage
    const minObtained = quoted.mul(99).div(100);
    const [, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, positionID);
    await strategy.connect(trader1).closePosition(positionID, minObtained);

    // vault should gain
    expect(await marginToken.balanceOf(vault.address)).to.be.above(vaultBalance.add(dueFees).sub(1));
  });

  it("Margin trading strategy: short position", async function () {
    vaultBalance = await investmentToken.balanceOf(vault.address);

    order.deadline = deadline;
    order.spentToken = investmentToken.address;
    order.obtainedToken = marginToken.address;
    order.collateralIsSpentToken = false;

    // check how many investments token margin * leverage margin tokens are worth
    const [toBorrow] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.maxSpent = toBorrow;

    // min obtained too high should revert
    order.minObtained = marginTokenMargin.mul(leverage).mul(11).div(10);
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;

    // 1% slippage
    order.minObtained = marginTokenMargin.mul(leverage).mul(99).div(100);
    await strategy.connect(trader1).openPosition(order);
  });

  it("Close short position", async function () {
    const positionID = 2;

    const position = await strategy.positions(positionID);
    const principal = position.principal;
    const [, dueFees] = await liquidatorContract.computeLiquidationScore(strategy.address, positionID);
    [quoted] = await strategy.quote(investmentToken.address, marginToken.address, principal.add(dueFees));

    // max spent too high should revert
    let maxSpent = position.allowance.add(1);
    await expect(strategy.connect(trader1).closePosition(positionID, maxSpent)).to.be.reverted;

    // 1% slippage
    maxSpent = quoted.mul(101).div(100);
    await strategy.connect(trader1).closePosition(positionID, maxSpent);

    // vault should gain
    expect(await investmentToken.balanceOf(vault.address)).to.be.above(vaultBalance.add(dueFees).sub(1));
  });
});
