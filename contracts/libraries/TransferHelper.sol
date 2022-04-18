// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultState } from "./VaultState.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

/// @title    TransferHelper library
/// @author   Ithil
/// @notice   A library to simplify handling taxed, rebasing and reflecting tokens
library TransferHelper {
    using SafeERC20 for IERC20;

    error TransferHelper__Insufficient_Token_Balance(address token, uint256 balance, uint256 amount);
    error TransferHelper__Insufficient_Token_Allowance(address token, uint256 allowance, uint256 amount);

    function transferTokens(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 originalBalance, uint256 received) {
        uint256 balanceFrom = token.balanceOf(from);
        uint256 allowanceFrom = token.allowance(from, address(this));
        if (balanceFrom < amount)
            revert TransferHelper__Insufficient_Token_Balance(address(token), balanceFrom, amount);

        if (allowanceFrom < amount)
            revert TransferHelper__Insufficient_Token_Allowance(address(token), allowanceFrom, amount);

        // computes transferred balance for tokens with tax on transfers
        originalBalance = token.balanceOf(to);
        token.safeTransferFrom(from, to, amount);

        received = token.balanceOf(to) - originalBalance;
    }

    function topUpCollateral(
        IERC20 token,
        IStrategy.Position storage position,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 originalBalance, uint256 received) {
        (originalBalance, received) = transferTokens(token, from, to, amount);
        position.collateral += received;
    }
}
