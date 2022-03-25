import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Liquidator } from "../src/types/Liquidator";
import type { MockToken } from "../src/types/MockToken";
import type { MockKyberNetworkProxy } from "../src/types/MockKyberNetworkProxy";
import type { MockTaxedToken } from "../src/types/MockTaxedToken";
import type { MockWETH } from "../src/types/MockWETH";
import type { MockYearnRegistry } from "../src/types/MockYearnRegistry";
import type { MockYearnVault } from "../src/types/MockYearnVault";
import type { Liquidable } from "../src/types/Liquidable";
import type { UniversalStrategy } from "../src/types/UniversalStrategy";
import type { YearnStrategy } from "../src/types/YearnStrategy";
import type { MarginTradingStrategy } from "../src/types/MarginTradingStrategy";
import type { Vault } from "../src/types/Vault";

declare module "mocha" {
  export interface Context {
    liquidator: Liquidator;
    mockKyberNetworkProxy: MockKyberNetworkProxy;
    mockTaxedToken: MockTaxedToken;
    mockToken: MockToken;
    mockWETH: MockWETH;
    mockYearnRegistry: MockYearnRegistry;
    mockYearnVault: MockYearnVault;
    liquidable: Liquidable;
    yearnStrategy: YearnStrategy;
    marginTradingStrategy: MarginTradingStrategy;
    universalStrategy: UniversalStrategy;
    vault: Vault;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  admin: SignerWithAddress;
  investor: SignerWithAddress;
  trader: SignerWithAddress;
  liquidator: SignerWithAddress;
}
