import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import { BigNumber, Wallet } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens } from "../../../common/mainnet";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";
import { yearnFixture } from "./fixture";

import { YearnStrategy } from "../../../../src/types/YearnStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";

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

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

describe("Yearn Strategy", function () {
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

    await vault.whitelistToken(marginToken.address, 10, 10, 1000, expandToNDecimals(1000000, 18));
    await vault.whitelistToken(investmentToken.address, 10, 10, 1, expandToNDecimals(1000, 18));

    await getTokens(staker.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(trader1.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await fundVault(signers[1], vault, marginToken, marginTokenLiquidity);

    await marginToken.connect(trader1).approve(strategy.address, marginTokenMargin);

    order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: marginTokenMargin, // todo: refine
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
  });

  it("Yearn Strategy: stake DAI and immediately close", async function () {
    await strategy.connect(trader1).openPosition(order);

    const maxSpent = (await strategy.positions(1)).allowance;
    expect(maxSpent).to.be.above(order.minObtained);

    await strategy.connect(trader1).closePosition(1, maxSpent);
  });
});
