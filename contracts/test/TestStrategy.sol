// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "../strategies/BaseStrategy.sol";

/// @dev Used for testing, unaudited
contract TestStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    constructor(address _vault, address _liquidator)
        BaseStrategy(_vault, _liquidator, "TestStrategy", "ITHIL-TS-POS")
    {}

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        return order.maxSpent;
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        IERC20(position.owedToken).safeTransfer(address(vault), position.allowance);

        return (position.allowance, position.allowance);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        return (amount, amount);
    }

    function arbitraryBorrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    ) external returns (uint256 baseInterestRate, uint256 fees) {
        (baseInterestRate, fees) = vault.borrow(token, amount, riskFactor, borrower);
    }

    function arbitraryRepay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        uint256 riskFactor,
        address borrower
    ) external {
        vault.repay(token, amount, debt, fees, riskFactor, borrower);
    }
    
    function exposure(address token) public view override returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
