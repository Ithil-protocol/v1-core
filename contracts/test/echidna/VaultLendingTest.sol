// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultEnvironmentSetup } from "./VaultEnvironmentSetup.sol";

/// @dev Used for testing, unaudited
contract VaultLendingTest is VaultEnvironmentSetup {
    mapping(address => uint256) public borrowed;

    constructor() {
        vault.stake(address(weth), type(uint128).max);
        vault.stake(address(dai), type(uint128).max);
        vault.stake(address(usdc), type(uint128).max);

        vault.addStrategy(address(this));
    }

    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor
    ) public {
        vault.borrow(token, amount, riskFactor, address(this));
        borrowed[token] -= amount;
    }

    function repay(
        address token,
        uint256 amount,
        uint256 riskFactor
    ) public {
        vault.repay(token, amount, amount, 0, riskFactor, address(this)); /// @todo this one fails
        borrowed[token] += amount;
    }

    function echidna_check_balances() public view returns (bool) {
        return (weth.balanceOf(address(vault)) == type(uint128).max - borrowed[address(weth)] &&
            dai.balanceOf(address(vault)) == type(uint128).max - borrowed[address(dai)] &&
            usdc.balanceOf(address(vault)) == type(uint128).max - borrowed[address(usdc)]);
    }
}
