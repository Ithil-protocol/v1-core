import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Liquidator } from "../src/types/Liquidator";
import type { Staker } from "../src/types/Staker";
import type { MockToken } from "../src/types/MockToken";
import type { MockKyberNetworkProxy } from "../src/types/MockKyberNetworkProxy";
import type { MockWETH } from "../src/types/MockWETH";
import type { MockYearnRegistry } from "../src/types/MockYearnRegistry";
import type { MockYearnVault } from "../src/types/MockYearnVault";
import type { TestStrategy } from "../src/types/TestStrategy";
import type { YearnStrategy } from "../src/types/YearnStrategy";
import type { MarginTradingStrategy } from "../src/types/MarginTradingStrategy";
import type { Vault } from "../src/types/Vault";

declare module "mocha" {
  export interface Context {
    liquidator: Liquidator;
    staker: Staker;
    mockKyberNetworkProxy: MockKyberNetworkProxy;
    mockToken: MockToken;
    mockWETH: MockWETH;
    mockYearnRegistry: MockYearnRegistry;
    mockYearnVault: MockYearnVault;
    yearnStrategy: YearnStrategy;
    marginTradingStrategy: MarginTradingStrategy;
    TestStrategy: TestStrategy;
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
