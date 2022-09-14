import { artifacts, ethers, waffle } from "hardhat";
import { BigNumber, Wallet } from "ethers";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens } from "../../../common/mainnet";
import { marginTokenLiquidity, marginTokenMargin, leverage } from "../../../common/params";
import { getTokens, expandToNDecimals, fundVault } from "../../../common/utils";

import { BalancerStrategy } from "../../../../src/types/BalancerStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";

import { balancerDAIWETH } from "./constants";
import { balancerFixture } from "./fixture";
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
let createStrategy: ThenArg<ReturnType<typeof balancerFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: BalancerStrategy;
let tokensAmount: BigNumber;

let marginTokenDAI: ERC20;
let investmentTokenDAI: ERC20;

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
    ({ WETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      balancerFixture,
    ));
    strategy = await createStrategy();
  });

  before("prepare vault with default parameters", async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    const staker = signers[1];

    const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    marginTokenDAI = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    investmentTokenDAI = <ERC20>await ethers.getContractAt(tokenArtifact.abi, balancerDAIWETH);

    await vault.whitelistToken(marginTokenDAI.address, 10, 10, 1000);
    await vault.whitelistToken(investmentTokenDAI.address, 10, 10, 1);

    await strategy.setRiskFactor(marginTokenDAI.address, 3000);
    await strategy.setRiskFactor(investmentTokenDAI.address, 4000);

    await strategy.addPool(balancerDAIWETH);

    await getTokens(staker.address, marginTokenDAI.address, tokens.DAI.whale, marginTokenLiquidity);
    await getTokens(trader1.address, marginTokenDAI.address, tokens.DAI.whale, marginTokenLiquidity);
    await fundVault(signers[1], vault, marginTokenDAI, marginTokenLiquidity);

    await marginTokenDAI.connect(trader1).approve(strategy.address, marginTokenMargin);

    order = {
      spentToken: marginTokenDAI.address,
      obtainedToken: balancerDAIWETH,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: BigNumber.from(2).pow(255),
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };

    console.log(order.maxSpent.toString());
  });

  it("Balancer Strategy: open position on DAI", async function () {
    const initialVaultBalance = await marginTokenDAI.balanceOf(vault.address);
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
    expect(await investmentTokenDAI.balanceOf(strategy.address)).to.equal(allowance);

    // Check that the vault has borrowed the expected tokens
    expect(await marginTokenDAI.balanceOf(vault.address)).to.equal(
      initialVaultBalance.sub(order.maxSpent.sub(order.collateral)),
    );
  });

  it("Balancer Strategy: close position on DAI", async function () {
    const initialVaultBalance = await marginTokenDAI.balanceOf(vault.address);
    const initialTraderBalance = await marginTokenDAI.balanceOf(trader1.address);
    // Calculate how much we will obtain
    const position = await strategy.positions(1);
    const [obtained] = await strategy.quote(position.heldToken, position.owedToken, position.allowance);

    // Revert if we want to obtain too much
    let minObtained = obtained.mul(11).div(10);
    await expect(strategy.connect(trader1).closePosition(1, minObtained)).to.be.reverted;

    // 0.1% slippage
    minObtained = obtained.mul(999).div(1000);
    const tx = await strategy
      .connect(trader1)
      .closePosition(1, minObtained, { gasPrice: ethers.utils.parseUnits("500", "gwei"), gasLimit: 30000000 });
    const receipt = await tx.wait();
    const amountIn = receipt.events?.[receipt.events?.length - 1].args?.amountIn as BigNumber;
    const dueFees = receipt.events?.[receipt.events?.length - 1].args?.fees as BigNumber;

    // Check that vault has gained
    expect(await marginTokenDAI.balanceOf(vault.address)).to.equal(
      initialVaultBalance.add(position.principal).add(dueFees),
    );

    // Check that the trader has the rest
    expect(await marginTokenDAI.balanceOf(trader1.address)).to.equal(
      initialTraderBalance.add(amountIn).sub(position.principal).sub(dueFees),
    );
  });

  // todo: test the same but with WETH
});
