// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title    Interface of IWETH contract
interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
