// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEulerMarkets } from "../interfaces/external/IEulerMarkets.sol";
import { IEulerEToken } from "../interfaces/external/IEulerEToken.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    EulerStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on any Euler market
contract EulerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    error EulerStrategy__Inexistent_Market(address token);

    IEulerMarkets internal immutable markets;
    address internal immutable euler;

    constructor(
        address _vault,
        address _liquidator,
        address _markets,
        address _euler
    ) BaseStrategy(_vault, _liquidator, "EulerStrategy", "ITHIL-ES-POS") {
        markets = IEulerMarkets(_markets);
        euler = _euler;
    }

    function _openPosition(Order calldata order) internal override returns (uint256) {
        address eToken = markets.underlyingToEToken(order.spentToken);
        IERC20 spentToken = IERC20(order.spentToken);
        if (eToken == address(0)) revert EulerStrategy__Inexistent_Market(order.spentToken);
        if (eToken != order.obtainedToken) revert Strategy__Incorrect_Obtained_Token();

        if (spentToken.allowance(address(this), euler) < order.maxSpent) spentToken.approve(euler, type(uint256).max);

        IEulerEToken eTkn = IEulerEToken(eToken);
        // must be called before, the deposit affects the exchange rate
        uint256 amountIn = eTkn.convertUnderlyingToBalance(order.maxSpent);
        eTkn.deposit(0, order.maxSpent);

        return amountIn;
    }

    function _closePosition(Position memory position, uint256 maxOrMin) internal override returns (uint256, uint256) {
        IEulerEToken eTkn = IEulerEToken(position.heldToken);
        uint256 amountOut = position.allowance;
        uint256 amountIn = eTkn.convertBalanceToUnderlying(position.allowance);
        // We only support underlying margin, therefore maxOrMin is always a min
        if (amountIn < maxOrMin) revert Strategy__Insufficient_Amount_Out(amountIn, maxOrMin);
        eTkn.withdraw(0, amountIn);

        IERC20(position.owedToken).safeTransfer(address(vault), amountIn);

        return (amountIn, amountOut);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        address eToken = markets.underlyingToEToken(src);
        uint256 obtained;
        if (eToken != address(0)) {
            obtained = IEulerEToken(eToken).convertUnderlyingToBalance(amount);
        } else {
            eToken = markets.underlyingToEToken(dst);
            obtained = IEulerEToken(eToken).convertBalanceToUnderlying(amount);
        }

        return (obtained, obtained);
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
