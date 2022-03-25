// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultState } from "./VaultState.sol";

/// @title    TransferHelper library
/// @author   Ithil
/// @notice   A library to simplify handling taxed, rebasing and reflecting tokens
library TransferHelper {
    using SafeERC20 for IERC20;

    error TransferHelper__Insufficient_Token_Balance(address);
    error TransferHelper__Insufficient_Token_Allowance(address);

    function transferTokens(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 originalBalance, uint256 received) {
        if (token.balanceOf(from) < amount) revert TransferHelper__Insufficient_Token_Balance(address(token));

        if (token.allowance(from, address(this)) < amount)
            revert TransferHelper__Insufficient_Token_Allowance(address(token));

        // computes transferred balance for tokens with tax on transfers
        originalBalance = token.balanceOf(to);
        token.safeTransferFrom(from, to, amount);

        received = token.balanceOf(to) - originalBalance;
    }
}
