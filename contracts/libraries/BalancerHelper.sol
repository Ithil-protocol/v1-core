// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VaultState } from "./VaultState.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";

/// @title    BalancerHelper library
/// @author   Ithil
/// @notice   A library to perform the most common operations on Balancer
library BalancerHelper {
    error BalancerStrategy__Token_Not_In_Pool(address token);

    struct PoolData {
        bytes32 id;
        address poolAddress;
        address[] tokens;
        uint8 length;
    }

    function getTokenIndex(address[] memory tokens, address token) internal pure returns (uint8) {
        for (uint8 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return i;
        }

        revert BalancerStrategy__Token_Not_In_Pool(token);
    }

    function joinPoolRequest(
        PoolData memory pool,
        address token,
        uint256 amount,
        uint256 minimumBPTOut
    ) internal pure returns (IBalancerVault.JoinPoolRequest memory) {
        uint256[] memory maxAmountsIn = new uint256[](pool.tokens.length);
        uint8 tokenIndex = getTokenIndex(pool.tokens, token);
        maxAmountsIn[tokenIndex] = amount;

        return
            IBalancerVault.JoinPoolRequest({
                assets: pool.tokens,
                maxAmountsIn: maxAmountsIn,
                userData: abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, minimumBPTOut),
                fromInternalBalance: false
            });
    }

    function exitPoolRequest(
        PoolData memory pool,
        address token,
        uint256 bptAmountIn,
        uint256 minObtained
    ) internal pure returns (IBalancerVault.ExitPoolRequest memory) {
        uint256[] memory minAmountsOut = new uint256[](pool.tokens.length);
        uint8 tokenIndex = getTokenIndex(pool.tokens, token);
        minAmountsOut[tokenIndex] = minObtained;

        return
            IBalancerVault.ExitPoolRequest({
                assets: pool.tokens,
                minAmountsOut: minAmountsOut,
                userData: abi.encode(
                    IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                    bptAmountIn,
                    tokenIndex
                ),
                toInternalBalance: false
            });
    }

    function getBalance(
        IBalancerVault balancerVault,
        PoolData memory pool,
        address token
    ) internal view returns (uint256 amount) {
        (, uint256[] memory totalBalances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(pool.id);
        IBalancerPool balancerPool = IBalancerPool(pool.poolAddress);

        uint256 underlyingIndex = BalancerHelper.getTokenIndex(pool.tokens, token);
        uint256 poolShare = (balancerPool.balanceOf(address(this)) * 1e18) / balancerPool.totalSupply();
        uint256[] memory underlyingBalances = new uint256[](pool.tokens.length);

        for (uint8 i = 0; i < pool.tokens.length; i++) {
            underlyingBalances[i] = totalBalances[i] * poolShare;
        }
        amount += underlyingBalances[0];

        IBalancerPool.SwapRequest memory request = IBalancerPool.SwapRequest(
            IBalancerPool.SwapKind.GIVEN_IN,
            IERC20(pool.tokens[1]),
            IERC20(pool.tokens[0]),
            underlyingBalances[1],
            pool.id,
            lastChangeBlock,
            address(this),
            address(this),
            abi.encode(0)
        );

        amount += balancerPool.onSwap(request, totalBalances, 1, underlyingIndex);

        return amount;
    }
}
