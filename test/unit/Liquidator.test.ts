import { artifacts, ethers, waffle } from "hardhat";
import { Wallet, BigNumber } from "ethers";
import { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Liquidator } from "../../src/types/Liquidator";
import { Vault } from "../../src/types/Vault";
import { MockWETH } from "../../src/types/MockWETH";
import { MockKyberNetworkProxy } from "../../src/types/MockKyberNetworkProxy";
import { MockToken } from "../../src/types/MockToken";
import { MarginTradingStrategy } from "../../src/types/MarginTradingStrategy";

import { mockMarginTradingFixture } from "../common/mockfixtures";
import { expandToNDecimals, fundVault, changeRate } from "../common/utils";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../common/params";

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

let marginToken: MockToken;
let investmentToken: MockToken;

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

    const tokenArtifact: Artifact = await artifacts.readArtifact("MockToken");
    marginToken = <MockToken>await waffle.deployContract(admin, tokenArtifact, ["Margin mock token", "MGN", 18]);
    investmentToken = <MockToken>(
      await waffle.deployContract(admin, tokenArtifact, ["Investment mock token", "INV", 18])
    );

    await vault.whitelistToken(marginToken.address, 10, 10, 1000, expandToNDecimals(1000000, 18));
    await vault.whitelistToken(investmentToken.address, 10, 10, 1, expandToNDecimals(1000, 18));

    // mint tokens to staker
    await marginToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader1).approve(strategy.address, ethers.constants.MaxUint256);

    // mint tokens to trader
    await marginToken.mintTo(trader1.address, expandToNDecimals(100000, 18));

    // mint tokens to liquidator and approve strategy contract (for margin call and purchase assets)
    await marginToken.mintTo(liquidator.address, expandToNDecimals(100000, 18));
    await marginToken.connect(liquidator).approve(strategy.address, ethers.constants.MaxUint256);

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

  it("Liquidator: liquidateSingle", async function () {
    const [minObtained] = await strategy.quote(
      marginToken.address,
      investmentToken.address,
      marginTokenMargin.mul(leverage),
    );

    order.minObtained = minObtained;

    await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    await strategy.connect(trader1).openPosition(order);

    await changeRate(mockKyberNetworkProxy, investmentToken, 93 * 10 ** 9);

    await liquidatorContract.connect(liquidator).liquidateSingle(strategy.address, 1);

    const position = await strategy.positions(1);
    expect(position.principal).to.equal(0);
  });

  it("Liquidator: marginCall", async function () {
    // await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    // await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    // await strategy.connect(trader1).openPosition(order);
    // await changeRate(mockKyberNetworkProxy, investmentToken, 93 * 10 ** 9);
    // await liquidatorContract.connect(liquidator).marginCall(strategy.address, 2, expandToNDecimals(10000,18));
  });

  it("Liquidator: purchaseAssets", async function () {
    // await changeRate(mockKyberNetworkProxy, marginToken, 1 * 10 ** 10);
    // await changeRate(mockKyberNetworkProxy, investmentToken, 10 * 10 ** 10);
    // await strategy.connect(trader1).openPosition(order);
    // await changeRate(mockKyberNetworkProxy, investmentToken, 93 * 10 ** 9);
    // await liquidatorContract.connect(liquidator).purchaseAssets(strategy.address, 3, expandToNDecimals(10,18));
  });
});
