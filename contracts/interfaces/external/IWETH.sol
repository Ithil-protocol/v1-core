// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title    Interface of the WETH contract
interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
