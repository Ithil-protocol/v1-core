// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the Convex boosted rewards contract
/// @author   Convex finance
interface IBooster {
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function depositAll(uint256 _pid, bool _stake) external returns (bool);
}
