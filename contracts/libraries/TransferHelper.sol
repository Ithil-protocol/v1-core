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

    function transferAsCollateral(IERC20 token, IStrategy.Order memory order) internal returns (uint256 toBorrow) {
        token.safeTransferFrom(msg.sender, address(this), order.collateral);
        toBorrow = order.collateralIsSpentToken ? order.maxSpent.positiveSub(order.collateral) : order.maxSpent;
    }
}
