// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

/// @title    Interface of Aura RewardPool contract
interface IAuraRewardPool4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function withdrawAndUnwrap(uint256 amount, bool claim) external;

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external;

    function getReward(address account, bool claimExtras) external;

    function periodFinish() external returns (uint256);
}
