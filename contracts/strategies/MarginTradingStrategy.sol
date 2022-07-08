// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../interfaces/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    MarginTradingStrategy contract
/// @author   Ithil
/// @notice   Uses Kyber network for swaps
contract MarginTradingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IKyberNetworkProxy public immutable kyberProxy;

    constructor(
        address _vault,
        address _liquidator,
        address _kyber
    ) BaseStrategy(_vault, _liquidator, "MarginTradingStrategy", "ITHIL-MS-POS") {
        kyberProxy = IKyberNetworkProxy(_kyber);
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        vault.checkWhitelisted(order.obtainedToken);

        (amountIn, ) = _swap(order.spentToken, order.obtainedToken, order.maxSpent, order.minObtained, address(this));
    }

    function _closePosition(Position memory position, uint256 maxOrMin)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        bool spendAll = position.collateralToken != position.heldToken;
        (amountIn, amountOut) = _swap(
            position.heldToken,
            position.owedToken,
            spendAll ? position.allowance : maxOrMin,
            spendAll ? maxOrMin : position.principal + position.fees,
            address(vault)
        );
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
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
        uint256 initialDstBalance = tokenToBuy.balanceOf(recipient);

        super._maxApprove(tokenToSell, address(kyberProxy));

        // slither-disable-next-line unused-return
        kyberProxy.trade(
            tokenToSell,
            maxSourceAmount,
            tokenToBuy,
            payable(recipient),
            type(uint256).max,
            minDestinationAmount / maxSourceAmount,
            payable(address(this))
        );
        amountIn = tokenToBuy.balanceOf(recipient) - initialDstBalance;
        amountOut = initialSrcBalance - tokenToSell.balanceOf(address(this));
    }
}
