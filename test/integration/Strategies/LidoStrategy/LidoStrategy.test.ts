import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens, stETH, stETHcrvPool, crvLPtoken, yearnRegistry } from "../../../common/mainnet";
import { getTokens } from "../../../common/utils";
import { marginTokenLiquidity } from "../../../common/params";

import { Liquidator } from "../../../../src/types/Liquidator";
import { LidoStrategy } from "../../../../src/types/LidoStrategy";

import { checkOpenPosition } from "./LidoStrategy.openPosition";
import { checkClosePosition } from "./LidoStrategy.closePosition";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("LidoStrategy", function () {
    // beforeEach(async function () {
    //   const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
    //   this.weth = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);
    //   await getTokens(this.signers.investor.address, tokens.WETH.address, tokens.WETH.whale, marginTokenLiquidity);
    //   await getTokens(this.signers.trader.address, tokens.WETH.address, tokens.WETH.whale, marginTokenLiquidity);
    //   this.dai = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
    //   await getTokens(this.signers.trader.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidity);
    //   const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
    //   this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.weth.address]);
    //   const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
    //   this.liquidator = <Liquidator>(
    //     await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
    //       "0x0000000000000000000000000000000000000000",
    //     ])
    //   );
    //   const ethArtifact: Artifact = await artifacts.readArtifact("LidoStrategy");
    //   this.LidoStrategy = <LidoStrategy>await waffle.deployContract(this.signers.admin, ethArtifact, [
    //     this.vault.address,
    //     this.liquidator.address,
    //     stETH,
    //     stETHcrvPool, // stETH-ETH Curve pool
    //     crvLPtoken, // Curve LP token
    //     yearnRegistry // Yearn Registry
    //   ]);
    //   await this.vault.addStrategy(this.LidoStrategy.address);
    // });
    // checkOpenPosition();
    // checkClosePosition();
  });
});
