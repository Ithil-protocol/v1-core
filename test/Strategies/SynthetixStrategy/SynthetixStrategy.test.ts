import { artifacts, ethers, waffle } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../../types";
import { Artifact } from "hardhat/types";
import { Liquidator } from "../../../src/types/Liquidator";
import { MockKyberNetworkProxy } from "../../../src/types/MockKyberNetworkProxy";
import { MockWETH } from "../../../src/types/MockWETH";
import { Vault } from "../../../src/types/Vault";
import { SynthetixStrategy } from "../../../src/types/SynthetixStrategy";

import { checkOpenPosition } from "./SynthetixStrategy.openPosition";
import { checkClosePosition } from "./SynthetixStrategy.closePosition";
import { checkQuote } from "./SynthetixStrategy.quote";
import { MockAddressResolver } from "../../../src/types/MockAddressResolver";
import { MockTaxedToken } from "../../../src/types/MockTaxedToken";
import { MockToken } from "../../../src/types/MockToken";
import { toUtf8Bytes32 } from "./synth.utils";

describe("Strategy tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
    this.signers.trader = signers[2];
    this.signers.liquidator = signers[3];
  });

  describe("SynthetixStrategy", function () {
    beforeEach(async function () {
      const liquidatorArtifact: Artifact = await artifacts.readArtifact("Liquidator");
      this.liquidator = <Liquidator>await waffle.deployContract(this.signers.admin, liquidatorArtifact, []);

      const kyberArtifact: Artifact = await artifacts.readArtifact("MockKyberNetworkProxy");
      this.mockKyberNetworkProxy = <MockKyberNetworkProxy>(
        await waffle.deployContract(this.signers.admin, kyberArtifact, [])
      );

      const wethArtifact: Artifact = await artifacts.readArtifact("MockWETH");
      this.mockWETH = <MockWETH>(
        await waffle.deployContract(this.signers.admin, wethArtifact, [this.mockKyberNetworkProxy.address])
      );

      const tknArtifact: Artifact = await artifacts.readArtifact("MockTaxedToken");
      this.mockTaxedToken = <MockTaxedToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          "Dai Stablecoin",
          "DAI",
          this.mockKyberNetworkProxy.address,
        ])
      );

      const mockTokenArtifact: Artifact = await artifacts.readArtifact("MockToken");
      this.mockToken = <MockToken>(
        await waffle.deployContract(this.signers.admin, tknArtifact, [
          "USD Coin",
          "USDC",
          this.mockKyberNetworkProxy.address,
        ])
      );

      const vaultArtifact: Artifact = await artifacts.readArtifact("Vault");
      this.vault = <Vault>await waffle.deployContract(this.signers.admin, vaultArtifact, [this.mockWETH.address]);

      const snxResolverArtifact: Artifact = await artifacts.readArtifact("MockAddressResolver");
      this.snxResolver = <MockAddressResolver>(
        await waffle.deployContract(this.signers.admin, snxResolverArtifact, [
          this.mockKyberNetworkProxy.address,
          this.mockToken.address,
        ])
      );

      const ssArtifact: Artifact = await artifacts.readArtifact("SynthetixStrategy");
      this.synthetixStrategy = <SynthetixStrategy>(
        await waffle.deployContract(this.signers.admin, ssArtifact, [
          this.snxResolver.address,
          this.vault.address,
          this.liquidator.address,
        ])
      );
      await this.vault.addStrategy(this.synthetixStrategy.address);

      await this.synthetixStrategy.registerCurrency(this.mockToken.address, toUtf8Bytes32("USDC"));
      await this.synthetixStrategy.registerCurrency(this.mockTaxedToken.address, toUtf8Bytes32("DAI"));
      await this.synthetixStrategy.registerCurrency(this.mockWETH.address, toUtf8Bytes32("WETH"));

      await this.snxResolver.registerToken(toUtf8Bytes32("USDC"), this.mockToken.address);
      await this.snxResolver.registerToken(toUtf8Bytes32("DAI"), this.mockTaxedToken.address);
      await this.snxResolver.registerToken(toUtf8Bytes32("WETH"), this.mockWETH.address);

      console.log(" ", this.synthetixStrategy.address);
      console.log(" ", this.snxResolver.address);
      console.log(" ", this.signers.trader.address);
    });

    checkOpenPosition();
    // checkClosePosition();
    // checkQuote();
  });
});
