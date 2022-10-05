// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

/// @title    Interface of Aura Booster contract
interface IAuraBooster {
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    function poolInfo(uint256 _pid)
        external
        returns (
            address lptoken,
            address token,
            address gauge,
            address crvRewards,
            address stash,
            bool shutdown
        );

    function crv() external pure returns (address);

    function minter() external pure returns (address);
}
