import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import { expect } from "chai";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { Vault } from "../../../../src/types/Vault";
import type { ERC20 } from "../../../../src/types/ERC20";
import { BalancerStrategy } from "../../../../src/types/BalancerStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";
import { Staker } from "../../../../src/types/Staker";
import { Ithil } from "../../../../src/types/Ithil";

import { tokens } from "../../../common/mainnet";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";

import { balancerPoolAddress, balancerPoolID, auraPoolID } from "./constants";
import { balancerFixture } from "./fixture";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let WETH: ERC20;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof balancerFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let ithilTokenContract: Ithil;
let stakerContract: Staker;
let liquidatorContract: Liquidator;
let strategy: BalancerStrategy;
let tokensAmount: BigNumber;

let marginToken: ERC20;
let investmentTokenBPT: ERC20;

let order: {
  spentToken: string;
  obtainedToken: string;
  collateral: BigNumber;
  collateralIsSpentToken: boolean;
  minObtained: BigNumber;
  maxSpent: BigNumber;
  deadline: number;
};

describe("Balancer strategy integration tests", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({
      WETH,
      admin,
      trader1,
      trader2,
      liquidator,
      vault,
      ithilTokenContract,
      stakerContract,
      liquidatorContract,
      createStrategy,
    } = await loadFixture(balancerFixture));
    strategy = await createStrategy();
  });

  before("prepare vault with default parameters", async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const staker = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    marginToken = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    investmentTokenBPT = <ERC20>await ethers.getContractAt(tokenArtifact.abi, balancerPoolAddress);
    
    await vault.whitelistToken(marginToken.address, 10, 10, 1000);
    await vault.whitelistToken(investmentTokenBPT.address, 10, 10, 1);

    await strategy.setRiskFactor(marginToken.address, 3000);
    await strategy.setRiskFactor(investmentTokenBPT.address, 4000);

    console.log(111111);
    await strategy.addPool(balancerPoolAddress, balancerPoolID, auraPoolID);
    console.log(222222);

    await getTokens(staker.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(trader1.address, marginToken.address, tokens.DAI.whale, marginTokenLiquidity);
    await fundVault(signers[1], vault, marginToken, marginTokenLiquidity);

    await marginToken.connect(trader1).approve(strategy.address, marginTokenMargin);

    order = {
      spentToken: marginToken.address,
      obtainedToken: balancerPoolAddress,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255),
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
  });

  it("Balancer Strategy: quoter", async function () {
    const [enter] = await strategy.quote(order.spentToken, order.obtainedToken, order.maxSpent);
    expect(enter).to.be.gt(0);
    const [exit] = await strategy.quote(order.obtainedToken, order.spentToken, order.maxSpent);
    expect(exit).to.be.gt(0);
  });

  it("Balancer Strategy: open position on DAI", async function () {
    const initialVaultBalance = await marginToken.balanceOf(vault.address);
    // First call should revert since minObtained is too high

    await expect(strategy.connect(trader1).openPosition(order)).to.be.reverted;

    const [firstQuote] = await strategy.quote(order.spentToken, order.obtainedToken, order.maxSpent);

    // 0.1% slippage
    order.minObtained = firstQuote.mul(999).div(1000);

    await strategy.connect(trader1).openPosition(order);

    const allowance = (await strategy.positions(1)).allowance;

    // 0.01% tolerance
    /// expect(allowance).to.be.above(firstQuote.mul(9999).div(10000));
    /// expect(allowance).to.be.below(firstQuote.mul(10001).div(10000));

    // Check that the strategy actually got the assets
    //expect(await investmentTokenBPT.balanceOf(strategy.address)).to.equal(allowance);

    // Check that the vault has borrowed the expected tokens
    /*expect(await marginToken.balanceOf(vault.address)).to.equal(
      initialVaultBalance.sub(order.maxSpent.sub(order.collateral)),
    );*/
  });

  it("Balancer Strategy: harvest", async function () {
    await strategy.harvest(order.obtainedToken);
  });

  it("Balancer Strategy: close position on DAI", async function () {
    const initialVaultBalance = await marginToken.balanceOf(vault.address);
    const initialTraderBalance = await marginToken.balanceOf(trader1.address);
    // Calculate how much we will obtain
    const position = await strategy.positions(1);
    const [obtained] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);

    // Revert if we want to obtain too much
    //let minObtained = obtained.mul(11).div(10);
    //await expect(strategy.connect(trader1).closePosition(1, minObtained)).to.be.reverted;

    // 0.1% slippage
    const minObtained = obtained.mul(999).div(1000);
    const tx = await strategy.connect(trader1).closePosition(1, minObtained);
    const receipt = await tx.wait();
    const amountIn = receipt.events?.[receipt.events?.length - 1].args?.amountIn as BigNumber;
    const dueFees = receipt.events?.[receipt.events?.length - 1].args?.fees as BigNumber;

    // Check that vault has gained
    expect(await marginToken.balanceOf(vault.address)).to.equal(
      initialVaultBalance.add(position.principal).add(dueFees),
    );

    // Check that the trader has the rest
    expect(await marginToken.balanceOf(trader1.address)).to.equal(
      initialTraderBalance.add(amountIn).sub(position.principal).sub(dueFees),
    );
  });

  // todo: test the same but with WETH
});
