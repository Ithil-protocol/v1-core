import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Vault } from "../../../../src/types/Vault";
import { Signers } from "../../../types";
import type { ERC20 } from "../../../../src/types/ERC20";

import { tokens, yearnRegistry, yearnPartnerTracker, yearnPartnerId } from "../../../common/mainnet";
import { getTokens } from "../../../common/utils";
import { marginTokenLiquidity } from "../../../common/params";

import { YearnStrategy } from "../../../../src/types/YearnStrategy";
import { Liquidator } from "../../../../src/types/Liquidator";

import { checkPerformInvestment } from "./YearnStrategy.invest";

describe("Strategy integration tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("YearnStrategy", function () {
    beforeEach(async function () {
      const tokenArtifact: Artifact = await artifacts.readArtifact("ERC20");
      this.weth = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.WETH.address);

      this.dai = <ERC20>await ethers.getContractAt(tokenArtifact.abi, tokens.DAI.address);
      await getTokens(this.signers.investor.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidity);
      await getTokens(this.signers.trader.address, tokens.DAI.address, tokens.DAI.whale, marginTokenLiquidity);

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>(
        await waffle.deployContract(this.signers.admin, vaultArtifact, [this.weth.address, this.signers.admin.address])
      );

      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>(
        await waffle.deployContract(this.signers.admin, liquidatorArtifact, [
          "0x0000000000000000000000000000000000000000",
        ])
      );

      const ysArtifact: Artifact = await artifacts.readArtifact("YearnStrategy");
      this.yearnStrategy = <YearnStrategy>(
        await waffle.deployContract(this.signers.admin, ysArtifact, [
          this.vault.address,
          this.liquidator.address,
          yearnRegistry,
          yearnPartnerId,
          yearnPartnerTracker,
        ])
      );

      await this.vault.addStrategy(this.yearnStrategy.address);
    });

    checkPerformInvestment();
  });
});
