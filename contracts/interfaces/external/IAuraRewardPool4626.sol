// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

/// @title    Interface of Aura RewardPool contract
interface IAuraRewardPool4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
}
