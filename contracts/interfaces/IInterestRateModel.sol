// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the InterestRateModel contract
/// @author   Ithil
interface IInterestRateModel {
    function computePairRiskFactor(uint256 rf0, uint256 rf1) external pure returns (uint256);

    function computeIR(
        uint256 baseIR,
        uint256 toBorrow,
        uint256 amountIn,
        uint256 initialExposure,
        uint256 collateral
    ) external view returns (uint256);

    function computeTimeFees(
        uint256 principal,
        uint256 interestRate,
        uint256 time
    ) external pure returns (uint256 dueFees);
}
