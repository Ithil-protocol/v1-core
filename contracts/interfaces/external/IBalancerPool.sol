// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBalancerVault } from "./IBalancerVault.sol";

/// @title    Interface of Balancer BasePool contract
interface IBalancerPool is IERC20 {
    /**
     * @dev Returns all normalized weights, in the same order as the Pool's tokens.
     */
    function getNormalizedWeights() external view returns (uint256[] memory);

    function getSwapFeePercentage() external view returns (uint256);
}
