// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/// @title    Interface of the Staker contract
/// @author   Ithil
interface IStaker is IERC20, IERC20Permit {
    function token() external view returns (IERC20);

    function rewardPercentage() external view returns (uint256);

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;
}
