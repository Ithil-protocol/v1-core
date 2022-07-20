// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEulerMarkets } from "../interfaces/external/IEulerMarkets.sol";
import { IEulerEToken } from "../interfaces/external/IEulerEToken.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

import "hardhat/console.sol";

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

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        address eToken = markets.underlyingToEToken(order.spentToken);
        if (eToken == address(0)) revert EulerStrategy__Inexistent_Market(order.spentToken);
        if (eToken != order.obtainedToken) revert Strategy__Incorrect_Obtained_Token();

        super._maxApprove(IERC20(order.spentToken), euler);

        IEulerEToken eTkn = IEulerEToken(eToken);
        // must be called before, the deposit affects the exchange rate
        amountIn = eTkn.convertUnderlyingToBalance(order.maxSpent);
        eTkn.deposit(0, order.maxSpent);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        IEulerEToken eTkn = IEulerEToken(position.heldToken);
        amountIn = eTkn.convertBalanceToUnderlying(position.allowance);
        eTkn.withdraw(0, amountIn);

        IERC20(position.owedToken).safeTransfer(address(vault), amountIn);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        address eToken = markets.underlyingToEToken(src);
        uint256 obtained = IEulerEToken(eToken).convertUnderlyingToBalance(amount);

        return (obtained, obtained);
    }
}
