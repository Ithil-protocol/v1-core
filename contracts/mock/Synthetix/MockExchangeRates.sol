// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IExchangeRates } from "synthetix/contracts/interfaces/IExchangeRates.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../../interfaces/IKyberNetworkProxy.sol";

contract MockExchangeRates is IExchangeRates {
    IKyberNetworkProxy kyber;

    constructor(address _kyber) {
        kyber = IKyberNetworkProxy(_kyber);
    }

    // Views
    function aggregators(bytes32 currencyKey) external view override returns (address) {
        return address(0);
    }

    function aggregatorWarningFlags() external view override returns (address) {
        return address(0);
    }

    function anyRateIsInvalid(bytes32[] calldata currencyKeys) external view override returns (bool) {
        return true;
    }

    function anyRateIsInvalidAtRound(bytes32[] calldata currencyKeys, uint256[] calldata roundIds)
        external
        view
        override
        returns (bool)
    {
        return true;
    }

    function currenciesUsingAggregator(address aggregator) external view override returns (bytes32[] memory) {
        bytes32[] memory k;
        return k;
    }

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view override returns (uint256 value) {
        value = 0;
    }

    function effectiveValueAndRates(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        override
        returns (
            uint256 value,
            uint256 sourceRate,
            uint256 destinationRate
        )
    {
        value = 0;
        sourceRate = 0;
        destinationRate = 0;
    }

    function effectiveValueAndRatesAtRound(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        uint256 roundIdForSrc,
        uint256 roundIdForDest
    )
        external
        view
        override
        returns (
            uint256 value,
            uint256 sourceRate,
            uint256 destinationRate
        )
    {
        value = 0;
        sourceRate = 0;
        destinationRate = 0;
    }

    function effectiveAtomicValueAndRates(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    )
        external
        view
        override
        returns (
            uint256 value,
            uint256 systemValue,
            uint256 systemSourceRate,
            uint256 systemDestinationRate
        )
    {
        value = 0;
        systemValue = 0;
        systemSourceRate = 0;
        systemDestinationRate = 0;
    }

    function getCurrentRoundId(bytes32 currencyKey) external view override returns (uint256) {
        return 0;
    }

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint256 startingRoundId,
        uint256 startingTimestamp,
        uint256 timediff
    ) external view override returns (uint256) {
        return 0;
    }

    function lastRateUpdateTimes(bytes32 currencyKey) external view override returns (uint256) {
        return 0;
    }

    function rateAndTimestampAtRound(bytes32 currencyKey, uint256 roundId)
        external
        view
        override
        returns (uint256 rate, uint256 time)
    {
        rate = 0;
        time = 0;
    }

    function rateAndUpdatedTime(bytes32 currencyKey) external view override returns (uint256 rate, uint256 time) {
        rate = 0;
        time = 0;
    }

    function rateAndInvalid(bytes32 currencyKey) external view override returns (uint256 rate, bool isInvalid) {
        rate = 0;
        isInvalid = true;
    }

    function rateForCurrency(bytes32 currencyKey) external view override returns (uint256) {
        //TODO:
        (uint256 a, ) = kyber.getExpectedRate(IERC20(address(0)), IERC20(address(0)), 1);
        return a;
    }

    function rateIsFlagged(bytes32 currencyKey) external view override returns (bool) {
        return true;
    }

    function rateIsInvalid(bytes32 currencyKey) external view override returns (bool) {
        return true;
    }

    function rateIsStale(bytes32 currencyKey) external view override returns (bool) {
        return true;
    }

    function rateStalePeriod() external view override returns (uint256) {
        return 0;
    }

    function ratesAndUpdatedTimeForCurrencyLastNRounds(
        bytes32 currencyKey,
        uint256 numRounds,
        uint256 roundId
    ) external view override returns (uint256[] memory rates, uint256[] memory times) {}

    function ratesAndInvalidForCurrencies(bytes32[] calldata currencyKeys)
        external
        view
        override
        returns (uint256[] memory rates, bool anyRateInvalid)
    {
        anyRateInvalid = true;
    }

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view override returns (uint256[] memory) {}

    function synthTooVolatileForAtomicExchange(bytes32 currencyKey) external view override returns (bool) {
        return true;
    }
}
