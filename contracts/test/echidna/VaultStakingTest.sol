// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultEnvironmentSetup } from "./VaultEnvironmentSetup.sol";

/// @dev Used for testing, unaudited
contract VaultStakingTest is VaultEnvironmentSetup {
    mapping(address => uint256) public staked;
    mapping(address => uint256) public boosted;

    function boost(address token, uint256 amount) public {
        vault.boost(token, amount);
        boosted[token] += amount;
    }

    function unboost(address token, uint256 amount) public {
        vault.unboost(token, amount);
        boosted[token] -= amount;
    }

    function stake(address token, uint256 amount) public {
        vault.stake(token, amount);
        staked[token] += amount;
    }

    function unstake(address token, uint256 amount) public {
        vault.unstake(token, amount);
        staked[token] -= amount;
    }

    function stakeETH() public payable {
        uint256 amount = msg.value;

        vault.stakeETH(amount);
        staked[address(weth)] += amount;
    }

    function unstakeETH(uint256 amount) public {
        vault.unstakeETH(amount);
        staked[address(weth)] -= amount;
    }

    function toggleLock(bool locked, address token) public {
        vault.toggleLock(locked, token);
    }

    function echidna_check_staking_weth() public view returns (bool) {
        uint256 balance = vault.balance(address(weth)) + boosted[address(weth)];

        return (weth.balanceOf(address(vault)) == balance &&
            balance == staked[address(weth)] + boosted[address(weth)] &&
            vault.claimable(address(weth)) == staked[address(weth)]);
    }

    function echidna_check_staking_dai() public view returns (bool) {
        uint256 balance = vault.balance(address(dai)) + boosted[address(dai)];

        return (dai.balanceOf(address(vault)) == balance &&
            balance == staked[address(dai)] + boosted[address(dai)] &&
            vault.claimable(address(dai)) == staked[address(dai)]);
    }

    function echidna_check_staking_usdc() public view returns (bool) {
        uint256 balance = vault.balance(address(usdc)) + boosted[address(usdc)];

        return (usdc.balanceOf(address(vault)) == balance &&
            balance == staked[address(usdc)] + boosted[address(usdc)] &&
            vault.claimable(address(usdc)) == staked[address(usdc)]);
    }
}
