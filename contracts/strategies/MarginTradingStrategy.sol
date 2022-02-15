// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../interfaces/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    MarginTradingStrategy contract
/// @author   Ithil
/// @notice   Uses Kyber network for swaps
contract MarginTradingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    IKyberNetworkProxy public immutable kyberProxy;

    constructor(address _kyber, address _vault) BaseStrategy(_vault) {
        kyberProxy = IKyberNetworkProxy(_kyber);
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        if (order.collateralIsSpentToken) borrowed += collateralReceived;
        (amountIn, ) = _swap(order.spentToken, order.obtainedToken, borrowed, order.minObtained, address(this));

        if (!order.collateralIsSpentToken) amountIn += collateralReceived;

        totalAllowances[order.obtainedToken] += amountIn;
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        _maxApprove(IERC20(position.owedToken), address(vault));

        if (position.collateralToken != position.heldToken) expectedCost = position.allowance;

        (amountIn, amountOut) = _swap(
            position.heldToken,
            position.owedToken,
            expectedCost,
            position.principal + position.fees,
            address(vault)
        );
    }

    function _quote(
        address src,
        address dst,
        uint256 amount
    ) internal view override returns (uint256, uint256) {
        return kyberProxy.getExpectedRate(IERC20(src), IERC20(dst), amount);
    }

    function _swap(
        address srcToken,
        address dstToken,
        uint256 maxSourceAmount,
        uint256 minDestinationAmount,
        address recipient
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        IERC20 tokenToSell = IERC20(srcToken);
        IERC20 tokenToBuy = IERC20(dstToken);

        uint256 initialSrcBalance = tokenToSell.balanceOf(address(this));

        _maxApprove(tokenToSell, address(kyberProxy));

        amountIn = kyberProxy.trade(
            tokenToSell,
            maxSourceAmount,
            tokenToBuy,
            payable(recipient),
            maxSourceAmount,
            minDestinationAmount / maxSourceAmount,
            payable(address(this))
        );

        amountOut = initialSrcBalance - tokenToSell.balanceOf(address(this));
    }

    function _maxApprove(IERC20 token, address receiver) internal {
        uint256 tokenAllowance = token.allowance(address(this), address(receiver));
        if (!(tokenAllowance > 0)) token.safeApprove(address(receiver), type(uint256).max);
    }
}
