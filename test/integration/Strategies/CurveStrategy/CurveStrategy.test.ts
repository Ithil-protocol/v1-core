import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens, convexBooster, crvToken, cvxToken } from "../../../common/mainnet";
import { getTokens } from "../../../common/utils";
import { marginTokenLiquidityUSDC } from "../../../common/params";

import { Liquidator } from "../../../../src/types/Liquidator";
import { CurveStrategy } from "../../../../src/types/CurveStrategy";

import { checkPerformInvestment } from "./CurveStrategy.invest";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("CurveStrategy", function () {
    beforeEach(async function () {
      const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
      this.usdc = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.USDC.address);
      await getTokens(this.signers.investor.address, tokens.USDC.address, tokens.USDC.whale, marginTokenLiquidityUSDC);
      await getTokens(this.signers.trader.address, tokens.USDC.address, tokens.USDC.whale, marginTokenLiquidityUSDC);

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [tokens.WETH.address]);

      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>(
        await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
          "0x0000000000000000000000000000000000000000",
        ])
      );

      const strategyArtifact: Artifact = await artifacts.readArtifact("CurveStrategy");
      this.curveStrategy = <CurveStrategy>(
        await waffle.deployContract(this.signers.admin, strategyArtifact, [
          this.vault.address,
          this.liquidator.address,
          convexBooster,
          crvToken,
          cvxToken,
        ])
      );

      await this.vault.addStrategy(this.curveStrategy.address);

      await this.curveStrategy.addCurvePool(
        this.usdc.address,
        54, // Convex pid
        "0x98a7F18d4E56Cfe84E3D081B40001B3d5bD3eB8B", // crvEURSUSDC
        2,
        0, // USDC coin index 0
      );
    });

    checkPerformInvestment();
  });
});
