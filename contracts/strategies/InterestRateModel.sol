// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { GeneralMath } from "../libraries/GeneralMath.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { IInterestRateModel } from "../interfaces/IInterestRateModel.sol";

/// @title    InterestRateModel
/// @author   Ithil
/// @notice   A contract to calculate interest rates
contract InterestRateModel is IInterestRateModel {
    using GeneralMath for uint256;

    uint256 public immutable MAX_RATE;

    error Maximum_Leverage_Exceeded();

    constructor(uint256 maxRate) {
        MAX_RATE = maxRate;
    }

    function computePairRiskFactor(uint256 rf0, uint256 rf1) external pure override returns (uint256) {
        if (rf0 == 0 || rf1 == 0) return 0;

        return (rf0 + rf1) / 2;
    }

    function computeIR(
        uint256 baseIR,
        uint256 toBorrow,
        uint256 amountIn,
        uint256 initialExposure,
        uint256 collateral
    ) external view override returns (uint256) {
        uint256 finalIR = baseIR;
        finalIR *= (toBorrow * (amountIn + 2 * initialExposure));
        finalIR /= (2 * collateral * (initialExposure + amountIn));
        if (finalIR > MAX_RATE) revert Maximum_Leverage_Exceeded();

        return finalIR;
    }

    function computeTimeFees(
        uint256 principal,
        uint256 interestRate,
        uint256 time
    ) external pure override returns (uint256 dueFees) {
        return
            (principal * interestRate * (time + 1)).ceilingDiv(
                uint32(VaultMath.TIME_FEE_WINDOW) * GeneralMath.RESOLUTION
            );
    }
}
