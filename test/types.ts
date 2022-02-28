import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { MarginTradingStrategy } from "../src/types/MarginTradingStrategy";
import type { MockKyberNetworkProxy } from "../src/types/MockKyberNetworkProxy";
import type { MockTaxedToken } from "../src/types/MockTaxedToken";
import type { MockWETH } from "../src/types/MockWETH";
import type { MockYearnRegistry } from "../src/types/MockYearnRegistry";
import type { MockYearnVault } from "../src/types/MockYearnVault";
import type { Vault } from "../src/types/Vault";
import type { YearnStrategy } from "../src/types/YearnStrategy";
import type { BaseStrategy } from "../src/types/BaseStrategy";

declare module "mocha" {
  export interface Context {
    marginTradingStrategy: MarginTradingStrategy;
    mockKyberNetworkProxy: MockKyberNetworkProxy;
    mockTaxedToken: MockTaxedToken;
    mockWETH: MockWETH;
    mockYearnRegistry: MockYearnRegistry;
    mockYearnVault: MockYearnVault;
    vault: Vault;
    yearnStrategy: YearnStrategy;
    baseStrategy: BaseStrategy;
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
