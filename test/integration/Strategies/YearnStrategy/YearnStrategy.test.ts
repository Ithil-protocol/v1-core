import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens } from "../../../common/mainnet";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";
import { marginTokenLiquidity, marginTokenMargin, leverage, investmentTokenLiquidity } from "../../../common/params";

import { YearnStrategy } from "../../../../src/types/YearnStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";

import { yvaultDAI, yvaultWETH } from "./constants";
import { yearnFixture } from "./fixture";

import { expect } from "chai";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let WETH: ERC20;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof yearnFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: YearnStrategy;
let tokensAmount: BigNumber;

let marginToken: ERC20;
let investmentToken: ERC20;
let yTokenDAI: ERC20;
let yTokenWETH: ERC20;

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

describe("Yearn Strategy integration test", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ WETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      yearnFixture,
    ));
    strategy = await createStrategy();
  });

  before("prepare vault with default parameters", async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const staker = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    marginToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    investmentToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);
    yTokenDAI = <ERC20>await ethers.getContractAt(tokenArtifact.abi, yvaultDAI);
    yTokenWETH = <ERC20>await ethers.getContractAt(tokenArtifact.abi, yvaultWETH);

    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(tokens.WETH.address, 10, 10, 1);

    await strategy.setRiskFactor(marginToken.address, 3000);
    await strategy.setRiskFactor(investmentToken.address, 4000);
    await strategy.setRiskFactor(yvaultDAI, 3000);
    await strategy.setRiskFactor(yvaultWETH, 4000);

    await getTokens(staker.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(trader1.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(staker.address, tokens.WETH.address, tokens.WETH.whale, investmentTokenLiquidity);
    await getTokens(trader1.address, tokens.WETH.address, tokens.WETH.whale, investmentTokenLiquidity);
    await fundVault(signers[1], vault, tokens.DAI, marginTokenLiquidity);
    await fundVault(signers[1], vault, tokens.WETH, investmentTokenLiquidity);

    await marginToken.connect(trader1).approve(strategy.address, marginTokenMargin);
    await investmentToken.connect(trader1).approve(strategy.address, marginTokenMargin.div(100));

    order = {
      spentToken: marginToken.address,
      obtainedToken: yvaultDAI,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255), // this order is invalid unless we reduce this parameter
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
  });

  it("Yearn Strategy: stake DAI", async function () {
    // First call should revert since minObtained is too high
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;

    const [firstQuote] = await strategy.quote(order.spentToken, order.obtainedToken, order.maxSpent);

    // 0.1% slippage
    order.minObtained = firstQuote.mul(999).div(1000);

    await strategy.connect(trader1).openPosition(order);

    const allowance = (await strategy.positions(1)).allowance;

    // 0.01% tolerance
    expect(allowance).to.be.above(firstQuote.mul(9999).div(10000));
    expect(allowance).to.be.below(firstQuote.mul(10001).div(10000));

    // Check that the strategy actually got the assets
    expect(await yTokenDAI.balanceOf(strategy.address)).to.equal(allowance);
  });

  it("Yearn strategy: unstake DAI", async function () {
    const position = await strategy.positions(1);
    const [expectedObtained] = await strategy.quote(order.obtainedToken, order.spentToken, position.allowance);

    // This position does not have margin in held token
    // Therefore the slippage parameter is a minimum obtained

    // Should fail if minimum obtained is too much
    await expect(strategy.connect(trader1).closePosition(1, expectedObtained.mul(11).div(10))).to.be.reverted;

    // Slippage of 0.1% should work
    await strategy.connect(trader1).closePosition(1, expectedObtained.mul(999).div(1000));
  });

  it("Yearn Strategy: stake WETH", async function () {
    order = {
      spentToken: tokens.WETH.address,
      obtainedToken: yvaultWETH,
      collateral: marginTokenMargin.div(100),
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255), // this order is invalid unless we reduce this parameter
      maxSpent: marginTokenMargin.div(100).mul(leverage),
      deadline: deadline,
    };

    // First call should revert since minObtained is too high
    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;
    const [firstQuote] = await strategy.quote(order.spentToken, order.obtainedToken, order.maxSpent);

    // 0.1% slippage
    order.minObtained = firstQuote.mul(999).div(1000);

    await strategy.connect(trader1).openPosition(order);

    const allowance = (await strategy.positions(2)).allowance;

    // 0.01% tolerance
    expect(allowance).to.be.above(firstQuote.mul(9999).div(10000));
    expect(allowance).to.be.below(firstQuote.mul(10001).div(10000));

    // Check that the strategy actually got the assets
    expect(await yTokenWETH.balanceOf(strategy.address)).to.equal(allowance);
  });

  it("Yearn strategy: unstake WETH", async function () {
    const position = await strategy.positions(2);
    const [expectedObtained] = await strategy.quote(order.obtainedToken, order.spentToken, position.allowance);

    // This position does not have margin in held token
    // Therefore the slippage parameter is a minimum obtained

    // Should fail if minimum obtained is too much
    await expect(strategy.connect(trader1).closePosition(2, expectedObtained.mul(11).div(10))).to.be.reverted;

    // Slippage of 0.1% should work
    await strategy.connect(trader1).closePosition(2, expectedObtained.mul(999).div(1000));
  });
});
