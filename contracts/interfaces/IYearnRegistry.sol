// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

interface IYearnRegistry {
    function latestVault(address token) external view returns (address);

    function newVault(address token) external returns (address);
}
