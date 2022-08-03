// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";
import { IKyberNetworkProxy } from "../interfaces/external/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    MarginTradingStrategy contract
/// @author   Ithil
/// @notice   Uses Kyber network for swaps
contract MarginTradingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IKyberNetworkProxy public immutable kyberProxy;
    FeedRegistryInterface public immutable feedRegistry;

    constructor(
        address _vault,
        address _liquidator,
        address _kyber,
        address _feed
    ) BaseStrategy(_vault, _liquidator, "MarginTradingStrategy", "ITHIL-MS-POS") {
        kyberProxy = IKyberNetworkProxy(_kyber);
        feedRegistry = FeedRegistryInterface(_feed);
    }

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
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
        int256 priceSrc;
        int256 priceDst;
        uint256 timestampSrc = 0;
        uint256 timestampDst = 0;

        (, priceSrc, , timestampSrc, ) = feedRegistry.latestRoundData(src, Denominations.USD);
        (, priceDst, , timestampDst, ) = feedRegistry.latestRoundData(dst, Denominations.USD);

        uint256 val = (uint256(priceSrc) / uint256(priceDst)) * amount;

        return (val, val);
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
