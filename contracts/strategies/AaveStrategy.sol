// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAaveLendingPool } from "../interfaces/external/IAaveLendingPool.sol";
import { IAaveAToken } from "../interfaces/external/IAaveAToken.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    AaveStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on any Aave markets
contract AaveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IAaveLendingPool internal immutable aave;

    constructor(
        address _vault,
        address _liquidator,
        address _aave
    ) BaseStrategy(_vault, _liquidator, "AaveStrategy", "ITHIL-AS-POS") {
        aave = IAaveLendingPool(_aave);
    }

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        IAaveAToken aToken = IAaveAToken(order.obtainedToken);
        address underlying = aToken.UNDERLYING_ASSET_ADDRESS();
        if (underlying != order.spentToken) revert Strategy__Incorrect_Obtained_Token();

        IERC20 spentToken = IERC20(order.spentToken);
        super._maxApprove(spentToken, address(aave));

        uint256 initialBalance = aToken.balanceOf(address(this));
        aave.deposit(order.spentToken, order.maxSpent, address(this), 0);
        amountIn = aToken.balanceOf(address(this)) - initialBalance;
    }

    function _closePosition(Position memory position, uint256 maxOrMin)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        IAaveAToken aTkn = IAaveAToken(position.heldToken);
        amountOut = position.allowance;
        amountIn = aTkn.scaledBalanceOf(address(this)) / position.allowance; /// @todo check it
        if (amountIn < maxOrMin) revert Strategy__Insufficient_Amount_Out(amountIn, maxOrMin);

        aave.withdraw(position.owedToken, position.allowance, address(vault));
        amountIn = position.allowance;
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        IAaveAToken aTkn = IAaveAToken(src);
        try aTkn.scaledBalanceOf(address(this)) returns (uint256 val) {
            return (val / amount, val / amount); /// @todo check it
        } catch {
            return (amount, amount);
        }
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
