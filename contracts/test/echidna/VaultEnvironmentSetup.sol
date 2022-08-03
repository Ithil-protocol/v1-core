// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Vault } from "../../Vault.sol";
import { MockToken } from "../../mock/MockToken.sol";
import { MockWETH } from "../../mock/MockWETH.sol";

/// @dev Used for testing, unaudited
contract VaultEnvironmentSetup {
    MockWETH public immutable weth;
    MockToken public immutable dai;
    MockToken public immutable usdc;
    Vault public immutable vault;
    address public wrappedToken;

    constructor() {
        weth = new MockWETH();
        dai = new MockToken("Dai Stablecoin", "DAI", 18);
        usdc = new MockToken("USD Coin", "USDC", 6);

        vault = new Vault(address(weth));
        vault.whitelistToken(address(weth), 0, 0, 1);
        vault.whitelistToken(address(dai), 0, 0, 1);
        vault.whitelistToken(address(usdc), 0, 0, 1);

        weth.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);

        weth.mintTo(address(this), type(uint128).max);
        dai.mintTo(address(this), type(uint128).max);
        usdc.mintTo(address(this), type(uint128).max);
    }
}
