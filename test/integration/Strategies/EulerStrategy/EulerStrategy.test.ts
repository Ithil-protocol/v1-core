import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens } from "../../../common/mainnet";
import { euler, eulerMarkets, etoken } from "./constants";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";

import { EulerStrategy } from "../../../../src/types/EulerStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";

import { eulerFixture } from "./fixture";
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
let createStrategy: ThenArg<ReturnType<typeof eulerFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: EulerStrategy;
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

describe("Euler strategy integration tests", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ WETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      eulerFixture,
    ));
    strategy = await createStrategy();
  });

  before("prepare vault with default parameters", async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const staker = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    marginToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    investmentToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, etoken);

    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(investmentToken.address, 10, 10, 1);

    await getTokens(staker.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(trader1.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await fundVault(signers[1], vault, marginToken, marginTokenLiquidity);

    await marginToken.connect(trader1).approve(strategy.address, marginTokenMargin);

    order = {
      spentToken: marginToken.address,
      obtainedToken: etoken,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255),
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
  });

  it("Euler Strategy: open position", async function () {
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
    expect(await investmentToken.balanceOf(strategy.address)).to.equal(allowance);
  });

  // await this.eulerStrategy
  // .connect(trader)
  // .closePosition(1, maxSpent, { gasPrice: ethers.utils.parseUnits("500", "gwei"), gasLimit: 30000000 });
});
