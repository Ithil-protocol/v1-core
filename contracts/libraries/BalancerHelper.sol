// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultState } from "./VaultState.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";

/// @title    BalancerHelper library
/// @author   Ithil
/// @notice   A library to perform the most common operations on Balancer
library BalancerHelper {
    error BalancerStrategy__Token_Not_In_Pool(address pool, address token);

    struct PoolData {
        bytes32 id;
        address poolAddress;
        address[] tokens;
        uint8 length;
    }

    function getTokenIndex(PoolData memory pool, address token) internal pure returns (uint8) {
        address[] memory tokens = pool.tokens;

        for (uint8 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) return i;
        }

        revert BalancerStrategy__Token_Not_In_Pool(pool.poolAddress, token);
    }

    function joinPoolRequest(
        PoolData memory pool,
        address token,
        uint256 maxSpent,
        uint256 minObtained
    ) internal pure returns (IBalancerVault.JoinPoolRequest memory) {
        uint256[] memory maxAmountsIn = new uint256[](pool.tokens.length);
        uint8 tokenIndex = getTokenIndex(pool, token);
        maxAmountsIn[tokenIndex] = maxSpent;
        return IBalancerVault.JoinPoolRequest({
            assets: pool.tokens,
            maxAmountsIn: maxAmountsIn,
            userData: abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, minObtained),
            fromInternalBalance: false
        });
    }

    function exitPoolRequest(
        PoolData memory pool,
        address token,
        uint256 maxSpent,
        uint256 minObtained
    ) internal pure returns (IBalancerVault.ExitPoolRequest memory) {
        uint256[] memory minAmountsOut = new uint256[](pool.tokens.length);
        uint8 tokenIndex = getTokenIndex(pool, token);
        minAmountsOut[tokenIndex] = maxSpent;

        return IBalancerVault.ExitPoolRequest({
            assets: pool.tokens,
            minAmountsOut: minAmountsOut,
            userData: abi.encodePacked(IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, minObtained, tokenIndex),
            toInternalBalance: false
        });
    }
}
