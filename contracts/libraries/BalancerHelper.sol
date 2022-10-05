// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
// import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { FloatingPointMath } from "./FloatingPointMath.sol";
import { VaultState } from "./VaultState.sol";

/// @title    BalancerHelper library
/// @author   Ithil
/// @notice   A library to perform the most common operations on Balancer
library BalancerHelper {
    error BalancerStrategy__Token_Not_In_Pool(address token);

    function getTokenIndex(address[] memory tokens, address token) internal pure returns (uint8) {
        for (uint8 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return i;
        }

        revert BalancerStrategy__Token_Not_In_Pool(token);
    }

    function joinPoolRequest(
        address[] memory tokens,
        address token,
        uint256 amount,
        uint256 minimumBPTOut
    ) internal pure returns (IBalancerVault.JoinPoolRequest memory) {
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        uint8 tokenIndex = getTokenIndex(tokens, token);
        maxAmountsIn[tokenIndex] = amount;

        return
            IBalancerVault.JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: maxAmountsIn,
                userData: abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, minimumBPTOut),
                fromInternalBalance: false
            });
    }

    function exitPoolRequest(
        address[] memory tokens,
        address token,
        uint256 bptAmountIn,
        uint256 minObtained
    ) internal pure returns (IBalancerVault.ExitPoolRequest memory) {
        uint256[] memory minAmountsOut = new uint256[](tokens.length);
        uint8 tokenIndex = getTokenIndex(tokens, token);
        minAmountsOut[tokenIndex] = minObtained;

        return
            IBalancerVault.ExitPoolRequest({
                assets: tokens,
                minAmountsOut: minAmountsOut,
                userData: abi.encode(IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, tokenIndex),
                toInternalBalance: false
            });
    }

    function computeBptOut(
        uint256 amountIn,
        uint256 totalBptSupply,
        uint256 totalTokenBalance,
        uint256 normalizedWeight,
        uint256 swapPercentageFee
    ) internal pure returns (uint256) {
        uint256 swapFee = FloatingPointMath.mul(
            FloatingPointMath.mul(amountIn, FloatingPointMath.REFERENCE - normalizedWeight),
            swapPercentageFee
        );
        uint256 balanceRatio = FloatingPointMath.div(totalTokenBalance + amountIn - swapFee, totalTokenBalance);
        uint256 invariantRatio = FloatingPointMath.power(balanceRatio, normalizedWeight);
        return
            invariantRatio > FloatingPointMath.REFERENCE
                ? FloatingPointMath.mul(totalBptSupply, invariantRatio - FloatingPointMath.REFERENCE)
                : 0;
    }

    function computeAmountOut(
        uint256 amountIn,
        uint256 totalBptSupply,
        uint256 totalTokenBalance,
        uint256 normalizedWeight,
        uint256 swapPercentageFee
    ) internal pure returns (uint256) {
        uint256 invariantRatio = FloatingPointMath.div(totalBptSupply - amountIn, totalBptSupply);
        uint256 balanceRatio = FloatingPointMath.power(
            invariantRatio,
            FloatingPointMath.div(FloatingPointMath.REFERENCE, normalizedWeight)
        );
        uint256 amountOutWithoutFee = FloatingPointMath.mul(
            totalTokenBalance,
            FloatingPointMath.complement(balanceRatio)
        );
        uint256 taxableAmount = FloatingPointMath.mul(
            amountOutWithoutFee,
            FloatingPointMath.complement(normalizedWeight)
        );
        uint256 nonTaxableAmount = FloatingPointMath.sub(amountOutWithoutFee, taxableAmount);
        uint256 taxableAmountMinusFees = FloatingPointMath.mul(
            taxableAmount,
            FloatingPointMath.complement(swapPercentageFee)
        );

        return nonTaxableAmount + taxableAmountMinusFees;
    }
}
