import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens, crvEURSUSDC, yearnRegistry, yearnPartnerTracker } from "../../../common/mainnet";
import { getTokens } from "../../../common/utils";
import { marginTokenLiquidityUSDC } from "../../../common/params";

import { Liquidator } from "../../../../src/types/Liquidator";
import { CurveStrategy } from "../../../../src/types/CurveStrategy";

import { checkOpenPosition } from "./CurveStrategy.openPosition";
import { checkClosePosition } from "./CurveStrategy.closePosition";

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

      this.dai = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
      await getTokens(this.signers.trader.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidityUSDC);

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [tokens.WETH.address]);

      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>(
        await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
          "0x0000000000000000000000000000000000000000",
        ])
      );

      const strategyArtifact: Artifact = await artifacts.readArtifact("CurveStrategy");
      this.CurveStrategy = <CurveStrategy>await waffle.deployContract(this.signers.admin, strategyArtifact, [
        this.vault.address,
        this.liquidator.address,
        yearnRegistry, // Yearn Registry
        this.vault.address, // Yearn partnerId
        yearnPartnerTracker,
      ]);

      await this.vault.addStrategy(this.CurveStrategy.address);

      await this.CurveStrategy.addCurvePool(this.usdc.address, crvEURSUSDC, false, 2); // Yearn-style pool, 2 tokens
    });

    checkOpenPosition();
    checkClosePosition();
  });
});
