// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IKyberNetworkProxy } from "../interfaces/external/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    MarginTradingStrategy contract
/// @author   Ithil
/// @notice   Uses Kyber network for swaps
contract MarginTradingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    error MarginTradingStrategy__Unsupported_Pair(address token0, address token1);

    IKyberNetworkProxy public immutable kyberProxy;

    constructor(
        address _vault,
        address _liquidator,
        address _kyber
    ) BaseStrategy(_vault, _liquidator, "MarginTradingStrategy", "ITHIL-MS-POS") {
        kyberProxy = IKyberNetworkProxy(_kyber);
    }

    function _openPosition(Order calldata order, bytes calldata extraParams) internal override returns (uint256) {
        vault.checkWhitelisted(order.obtainedToken);

        (uint256 amountIn, ) = _swap(
            order.spentToken,
            order.obtainedToken,
            order.maxSpent,
            order.minObtained,
            address(this)
        );

        return amountIn;
    }

    function _closePosition(Position memory position, uint256 maxOrMin) internal override returns (uint256, uint256) {
        bool spendAll = position.collateralToken != position.heldToken;
        (uint256 amountIn, uint256 amountOut) = _swap(
            position.heldToken,
            position.owedToken,
            spendAll ? position.allowance : maxOrMin,
            spendAll ? maxOrMin : position.principal + position.fees,
            address(vault)
        );

        return (amountIn, amountOut);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        (uint256 rate, ) = kyberProxy.getExpectedRate(IERC20(src), IERC20(dst), amount);
        uint256 ratedUnit = 10**IERC20Metadata(src).decimals();

        return ((rate * amount) / ratedUnit, (rate * amount) / ratedUnit);
    }

    function _swap(
        address srcToken,
        address dstToken,
        uint256 maxSourceAmount,
        uint256 minDestinationAmount,
        address recipient
    ) internal returns (uint256, uint256) {
        IERC20 tokenToSell = IERC20(srcToken);
        IERC20 tokenToBuy = IERC20(dstToken);

        uint256 initialDstBalance = tokenToBuy.balanceOf(recipient);

        if (tokenToSell.allowance(address(this), address(kyberProxy)) < maxSourceAmount)
            tokenToSell.approve(address(kyberProxy), type(uint256).max);

        try
            kyberProxy.trade(
                tokenToSell,
                maxSourceAmount,
                tokenToBuy,
                payable(recipient),
                type(uint256).max,
                minDestinationAmount / maxSourceAmount,
                payable(address(this))
            )
        {
            uint256 amountIn = tokenToBuy.balanceOf(recipient) - initialDstBalance;
            uint256 amountOut = maxSourceAmount;

            return (amountIn, amountOut);
        } catch {
            revert MarginTradingStrategy__Unsupported_Pair(address(tokenToSell), address(tokenToBuy));
        }
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
