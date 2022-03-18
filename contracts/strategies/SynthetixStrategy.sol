// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAddressResolver } from "synthetix/contracts/interfaces/IAddressResolver.sol";
import { ISynthetix } from "synthetix/contracts/interfaces/ISynthetix.sol";
import { IExchangeRates } from "synthetix/contracts/interfaces/IExchangeRates.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    Synthetix strategy contract
/// @author   Ithil
/// @notice   For Synthetix
contract SynthetixStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    mapping(address => bytes32) currencyKeyMap;
    mapping(bytes32 => address) currencyKeyMapRev;

    IAddressResolver public synthetixResolver;
    ISynthetix public synthetix;
    IExchangeRates public exchangeRates;

    constructor(
        address _snxResolver,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        synthetixResolver = IAddressResolver(_snxResolver);
        synthetix = ISynthetix(synthetixResolver.getAddress("Synthetix"));
        exchangeRates = IExchangeRates(synthetixResolver.getAddress("ExchangeRates"));
        require(address(synthetix) != address(0), "Synthetix is missing from Synthetix resolver");
        require(address(exchangeRates) != address(0), "ExchangeRates is missing from Synthetix resolver");
    }

    function name() external pure override returns (string memory) {
        return "SynthetixStrategy";
    }

    function registerCurrency(address token, bytes32 currencyKey) external onlyOwner {
        currencyKeyMap[token] = currencyKey;
        currencyKeyMapRev[currencyKey] = token;
    }

    function isRegisteredCurrency(address token) public returns (bool) {
        return currencyKeyMap[token] != bytes32(0);
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        require(isRegisteredCurrency(order.obtainedToken), "not registered currency");
        require(isRegisteredCurrency(order.spentToken), "not registered currency");

        (amountIn, ) = _swap(order.spentToken, order.obtainedToken, order.minObtained, address(this));

        totalAllowances[order.obtainedToken] += amountIn;
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        require(isRegisteredCurrency(position.heldToken), "not registered currency");
        require(isRegisteredCurrency(position.owedToken), "not registered currency");

        _maxApprove(IERC20(position.owedToken), address(vault));

        (amountIn, amountOut) = _swap(
            position.heldToken,
            position.owedToken,
            position.principal + position.fees,
            address(vault)
        );
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        bytes32 srcCurrencyKey = currencyKeyMap[src];
        bytes32 dstCurrencyKey = currencyKeyMap[dst];

        uint256 rateSrc = exchangeRates.rateForCurrency(srcCurrencyKey);
        uint256 rateDst = exchangeRates.rateForCurrency(dstCurrencyKey);

        return (rateSrc, rateDst);
    }

    function _swap(
        address srcToken,
        address dstToken,
        uint256 amount,
        address recipient
    ) internal returns (uint256 amountIn, uint256 amountOut) {
        IERC20 tokenToSell = IERC20(srcToken);
        IERC20 tokenToBuy = IERC20(dstToken);

        bytes32 sellCurrencyKey = currencyKeyMap[srcToken];
        bytes32 buyCurrencyKey = currencyKeyMap[dstToken];

        uint256 initialSrcBalance = tokenToSell.balanceOf(address(this));

        _maxApprove(tokenToSell, address(synthetix));

        amountIn = synthetix.exchange(sellCurrencyKey, amount, buyCurrencyKey);

        amountOut = initialSrcBalance - tokenToSell.balanceOf(address(this));
    }

    function _maxApprove(IERC20 token, address receiver) internal {
        uint256 tokenAllowance = token.allowance(address(this), address(receiver));
        if (!(tokenAllowance > 0)) token.safeApprove(address(receiver), type(uint256).max);
    }
}
