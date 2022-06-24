// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultState } from "./VaultState.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { GeneralMath } from "./GeneralMath.sol";

/// @title    TransferHelper library
/// @author   Ithil
/// @notice   A library to simplify handling taxed, rebasing and reflecting tokens
library TransferHelper {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    error TransferHelper__Insufficient_Token_Balance(address from, address token);
    error TransferHelper__Insufficient_Token_Allowance(address owner, address spender, address token);
    error TransferHelper__Sending_Too_Much(address sender, address token);

    function transferTokens(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 originalBalance, uint256 received) {
        if (token.balanceOf(from) < amount) revert TransferHelper__Insufficient_Token_Balance(from, address(token));

        if (token.allowance(from, address(this)) < amount)
            revert TransferHelper__Insufficient_Token_Allowance(from, address(this), address(token));

        // computes transferred balance for tokens with tax on transfers
        originalBalance = token.balanceOf(to);
        token.safeTransferFrom(from, to, amount);

        received = token.balanceOf(to) - originalBalance;
    }

    function sendTokens(
        IERC20 token,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        if (token.balanceOf(address(this)) < amount)
            revert TransferHelper__Sending_Too_Much(address(this), address(token));

        // computes transferred balance for tokens with tax on transfers
        uint256 balance = token.balanceOf(to);
        token.safeTransfer(to, amount);

        return token.balanceOf(to) - balance;
    }

    function transferAsCollateral(IERC20 token, IStrategy.Order memory order)
        internal
        returns (
            uint256 collateralReceived,
            uint256 toBorrow,
            uint256 originalCollBal
        )
    {
        (originalCollBal, collateralReceived) = transferTokens(token, msg.sender, address(this), order.collateral);
        toBorrow = order.collateralIsSpentToken ? order.maxSpent.positiveSub(collateralReceived) : order.maxSpent;
    }
}
