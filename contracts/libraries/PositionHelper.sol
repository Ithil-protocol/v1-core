// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IStrategy.sol";
import { TransferHelper } from "./TransferHelper.sol";

library PositionHelper {
    using TransferHelper for IERC20;

    function topUpCollateral(
        IStrategy.Position storage self,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 originalBalance, uint256 received) {
        (originalBalance, received) = IERC20(self.collateralToken).transferTokens(from, to, amount);
        self.collateral += received;
    }
}
