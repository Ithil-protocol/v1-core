// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the Convex base reward contract
/// @author   Convex finance
interface IBaseRewardPool {
    function withdrawAndUnwrap(uint256 amount, bool claim) external returns (bool);

    function withdrawAllAndUnwrap(bool claim) external;

    function getReward(address _account, bool _claimExtras) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function earned(address) external view returns (uint256);
}
