import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Artifact } from "hardhat/types";
import { Wallet, BigNumber } from "ethers";
import { expect } from "chai";

import { Liquidator } from "../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { Vault } from "../../../src/types/Vault";
import { TestStrategy } from "../../../src/types/TestStrategy";
import { MockToken } from "../../../src/types/MockToken";
import { IStrategy } from "../../../src/types/MarginTradingStrategy";

import { mockTestFixture } from "../../common/mockfixtures";
import { getPermitDigest, sign } from "../../common/permit";
import { expandToNDecimals, fundVault } from "../../common/utils";
import { marginTokenMargin, marginTokenLiquidity, leverage, investmentTokenLiquidity } from "../../common/params";

const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from the current Unix time

const createFixtureLoader = waffle.createFixtureLoader;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

let wallet: Wallet, other: Wallet;

let mockWETH: MockWETH;
let admin: SignerWithAddress;
let trader1: SignerWithAddress;
let trader2: SignerWithAddress;
let liquidator: SignerWithAddress;
let createStrategy: ThenArg<ReturnType<typeof mockTestFixture>>["createStrategy"];
let loadFixture: ReturnType<typeof createFixtureLoader>;

let vault: Vault;
let liquidatorContract: Liquidator;
let strategy: TestStrategy;
let tokensAmount: BigNumber;
let mockKyberNetworkProxy: MockKyberNetworkProxy;

let marginToken: MockToken;
let investmentToken: MockToken;

let order: IStrategy.OrderStruct;

const riskFactor = BigNumber.from(100);
const fixedFee = BigNumber.from(10);

describe("Test strategy unit tests", function () {
  before("create fixture loader", async () => {
    [wallet, other] = await (ethers as any).getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  before("load fixtures", async () => {
    ({ mockWETH, admin, trader1, trader2, liquidator, vault, liquidatorContract, createStrategy } = await loadFixture(
      mockTestFixture,
    ));
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

    // mint tokens to staker
    await marginToken.mintTo(staker.address, expandToNDecimals(100000, 18));
    await fundVault(staker, vault, marginToken, marginTokenLiquidity);
    await marginToken.connect(trader1).approve(strategy.address, ethers.constants.MaxUint256);

    // mint tokens to trader
    await marginToken.mintTo(trader1.address, marginTokenMargin.mul(leverage));

    order = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      collateralIsSpentToken: true,
      minObtained: investmentTokenLiquidity,
      maxSpent: marginTokenMargin.mul(leverage),
      deadline: deadline,
    };
    await strategy.setRiskFactor(marginToken.address, 3000);
    await strategy.setRiskFactor(investmentToken.address, 4000);
  });
  // checkSetRiskFactor();
  // checkGetPosition();
  // checkTotalAllowance();
  // checkOpenPosition();
  // checkClosePosition();
  // checkEditPosition();
  it("TestStrategy: status", async function () {
    const quote = await strategy.quote(mockWETH.address, mockWETH.address, marginTokenMargin);
    expect(quote[0]).to.equal(marginTokenMargin);
    expect(quote[1]).to.equal(marginTokenMargin);

    expect(await strategy.balanceOf(admin.address)).to.equal(0);
    expect(await strategy.name()).to.equal("TestStrategy");
    expect(await strategy.symbol()).to.equal("ITHIL-TS-POS");
  });

  it("NFT transfer check and close", async function () {
    await strategy.connect(trader1).openPosition(order);
    await expect(strategy.connect(admin).transferFrom(admin.address, trader1.address, 1)).to.be.reverted;

    expect(await strategy.balanceOf(trader1.address)).to.be.equal(1);
    await strategy.connect(trader1).transferFrom(trader1.address, admin.address, 1);
    expect(await strategy.ownerOf(1)).to.be.equal(admin.address);
    expect(await strategy.balanceOf(trader1.address)).to.be.equal(0);
    expect(await strategy.balanceOf(admin.address)).to.be.equal(1);

    await strategy.connect(admin).closePosition(1, 0);

    expect(await marginToken.balanceOf(admin.address)).to.be.gt(0);
    expect(await strategy.balanceOf(trader1.address)).to.be.equal(0);
    expect(await strategy.balanceOf(admin.address)).to.be.equal(0);
  });

  it("Arbitrary borrow", async function () {
    await strategy.arbitraryBorrow(marginToken.address, marginTokenMargin, riskFactor, trader1.address);
  });

  it("Arbitrary repay", async function () {
    await strategy.arbitraryRepay(
      marginToken.address,
      marginTokenMargin,
      marginTokenMargin,
      fixedFee,
      riskFactor,
      trader1.address,
    );
  });

  it("Deadline error", async function () {
    const order: IStrategy.OrderStruct = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: marginTokenMargin,
      minObtained: 1,
      maxSpent: 1,
      deadline: 1,
      collateralIsSpentToken: true,
    };
    await expect(strategy.openPosition(order)).to.be.reverted;
  });

  it("Equal tokens error", async function () {
    const order: IStrategy.OrderStruct = {
      spentToken: marginToken.address,
      obtainedToken: marginToken.address,
      collateral: marginTokenMargin,
      minObtained: 1,
      maxSpent: 1,
      deadline: 1700000000,
      collateralIsSpentToken: true,
    };
    await expect(strategy.openPosition(order)).to.be.reverted;
  });

  it("Null collateral error", async function () {
    const order: IStrategy.OrderStruct = {
      spentToken: marginToken.address,
      obtainedToken: investmentToken.address,
      collateral: 0,
      minObtained: 1,
      maxSpent: 1,
      deadline: 1700000000,
      collateralIsSpentToken: true,
    };
    await expect(strategy.openPosition(order)).to.be.reverted;
  });

  it("Insufficient balance error", async function () {
    await expect(strategy.connect(admin).openPosition(order)).to.be.reverted;
  });

  it("open position with permit", async function () {
    const address = "0x67d30ef950015Ab1a03e30ED5d5F2A26de196C4d";
    const privateKey = "c429601ee7a6167356f15baa70fd8fe17b0325dab7047a658a31039e5384bffd";
    const signer: SignerWithAddress = await ethers.getImpersonatedSigner(address);

    await marginToken.mintTo(address, expandToNDecimals(100000, 18));

    const nonce = await marginToken.nonces(address);
    const approve = {
      owner: address,
      spender: strategy.address,
      value: order.maxSpent,
    };
    const digest = getPermitDigest(
      await marginToken.name(),
      marginToken.address,
      await wallet.getChainId(),
      approve,
      nonce,
      order.deadline,
    );
    const privateKeyBuffer = Buffer.from(privateKey, "hex");
    const { v, r, s } = sign(digest, privateKeyBuffer);

    await admin.sendTransaction({
      to: address,
      value: ethers.utils.parseEther("10.0"),
    });
    await expect(strategy.connect(signer).openPosition(order)).to.be.reverted;
    await strategy.connect(signer).openPositionWithPermit(order, v, r, s);
  });
});
