// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

/// @title    Interface of IWETH contract
interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
