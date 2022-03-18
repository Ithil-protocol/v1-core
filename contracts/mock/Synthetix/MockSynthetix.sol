// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { ISynthetix } from "synthetix/contracts/interfaces/ISynthetix.sol";
import { ISynth } from "synthetix/contracts/interfaces/ISynth.sol";
import { IVirtualSynth } from "synthetix/contracts/interfaces/IVirtualSynth.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../../interfaces/IKyberNetworkProxy.sol";

contract MockSynthetix is ISynthetix {
    IKyberNetworkProxy kyber;

    constructor(address _kyber) {
        kyber = IKyberNetworkProxy(_kyber);
    }

    // Views
    function anySynthOrSNXRateIsInvalid() external view override returns (bool anyRateInvalid) {
        anyRateInvalid = false;
    }

    function availableCurrencyKeys() external view override returns (bytes32[] memory) {
        bytes32[] memory b;
        return b;
    }

    function availableSynthCount() external view override returns (uint256) {
        return 0;
    }

    function availableSynths(uint256 index) external view override returns (ISynth) {
        return ISynth(address(0));
    }

    function collateral(address account) external view override returns (uint256) {
        return 0;
    }

    function collateralisationRatio(address issuer) external view override returns (uint256) {
        return 0;
    }

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view override returns (uint256) {
        return 0;
    }

    function isWaitingPeriod(bytes32 currencyKey) external view override returns (bool) {
        return true;
    }

    function maxIssuableSynths(address issuer) external view override returns (uint256 maxIssuable) {
        return 0;
    }

    function remainingIssuableSynths(address issuer)
        external
        view
        override
        returns (
            uint256 maxIssuable,
            uint256 alreadyIssued,
            uint256 totalSystemDebt
        )
    {
        maxIssuable = 0;
        alreadyIssued = 0;
        totalSystemDebt = 0;
    }

    function synths(bytes32 currencyKey) external view override returns (ISynth) {
        return ISynth(address(0));
    }

    function synthsByAddress(address synthAddress) external view override returns (bytes32) {
        return bytes32("");
    }

    function totalIssuedSynths(bytes32 currencyKey) external view override returns (uint256) {
        return 0;
    }

    function totalIssuedSynthsExcludeOtherCollateral(bytes32 currencyKey) external view override returns (uint256) {
        return 0;
    }

    function transferableSynthetix(address account) external view override returns (uint256 transferable) {
        return 0;
    }

    // Mutative Functions
    function burnSynths(uint256 amount) external override {}

    function burnSynthsOnBehalf(address burnForAddress, uint256 amount) external override {}

    function burnSynthsToTarget() external override {}

    function burnSynthsToTargetOnBehalf(address burnForAddress) external override {}

    function exchange(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    ) external override returns (uint256 amountReceived) {
        //TODO:
        return
            kyber.trade(IERC20(address(0)), 0, IERC20(address(0)), payable(address(0)), 0, 0, payable(address(this)));
    }

    function exchangeOnBehalf(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    ) external override returns (uint256 amountReceived) {
        amountReceived = 0;
    }

    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external override returns (uint256 amountReceived) {
        amountReceived = 0;
    }

    function exchangeWithTrackingForInitiator(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external override returns (uint256 amountReceived) {
        amountReceived = 0;
    }

    function exchangeOnBehalfWithTracking(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external override returns (uint256 amountReceived) {
        amountReceived = 0;
    }

    function exchangeWithVirtual(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode
    ) external override returns (uint256 amountReceived, IVirtualSynth vSynth) {
        amountReceived = 0;
        vSynth = IVirtualSynth(address(0));
    }

    function exchangeAtomically(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode
    ) external override returns (uint256 amountReceived) {
        amountReceived = 0;
    }

    function issueMaxSynths() external override {}

    function issueMaxSynthsOnBehalf(address issueForAddress) external override {}

    function issueSynths(uint256 amount) external override {}

    function issueSynthsOnBehalf(address issueForAddress, uint256 amount) external override {
        issueForAddress = address(0);
        amount = 0;
    }

    function mint() external override returns (bool) {
        return true;
    }

    function settle(bytes32 currencyKey)
        external
        override
        returns (
            uint256 reclaimed,
            uint256 refunded,
            uint256 numEntries
        )
    {
        reclaimed = 0;
        refunded = 0;
        numEntries = 0;
    }

    // Liquidations
    function liquidateDelinquentAccount(address account, uint256 susdAmount) external override returns (bool) {
        return true;
    }

    // Restricted Functions

    function mintSecondary(address account, uint256 amount) external override {}

    function mintSecondaryRewards(uint256 amount) external override {}

    function burnSecondary(address account, uint256 amount) external override {}
}
