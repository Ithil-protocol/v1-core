// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { TransferHelper } from "./TransferHelper.sol";

/// @title    PositionHelper library
/// @author   Ithil
/// @notice   A library to increase the collateral on existing positions
library PositionHelper {
    using SafeERC20 for IERC20;

    function topUpCollateral(
        IStrategy.Position storage self,
        address from,
        address to,
        uint256 amount,
        bool collateralIsOwedToken
    ) internal {
        IERC20(self.collateralToken).safeTransferFrom(from, to, amount);
        collateralIsOwedToken ? self.principal -= amount : self.allowance += amount;
    }
}
