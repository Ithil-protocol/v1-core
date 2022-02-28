// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../interfaces/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    Universal strategy contract
/// @author   Ithil
/// @notice   For testing
contract UniversalStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    constructor(address _vault) BaseStrategy(_vault) {}

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {}

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {}

    function _quote(
        address src,
        address dst,
        uint256 amount
    ) internal view override returns (uint256, uint256) {
        return (0, 0);
    }

    function arbitraryBorrow(
        address token,
        uint256 amount,
        uint256 collateral,
        uint256 riskFactor,
        address borrower
    ) external {
        vault.borrow(token, amount, collateral, riskFactor, borrower);
    }

    function arbitraryRepay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        address borrower
    ) external {
        vault.repay(token, amount, debt, fees, borrower);
    }
}
