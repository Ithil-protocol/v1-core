// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultState } from "./VaultState.sol";
import { GeneralMath } from "./GeneralMath.sol";

/// @title    VaultMath library
/// @author   Ithil
/// @notice   A library to calculate vault-related stuff, like APY, lending interests, max withdrawable tokens
library VaultMath {
    using GeneralMath for uint256;

    uint24 internal constant RESOLUTION = 10000;
    uint24 internal constant TIME_FEE_PERIOD = 86400;
    uint24 internal constant MAX_RATE = 500;

    uint256 internal constant DEGRADATION_COEFFICIENT = 21600; // six hours

    /// @notice Computes the maximum amount of money an investor can withdraw from the pool
    /// @dev Floor(x+y) >= Floor(x) + Floor(y), therefore the sum of all investors'
    /// withdrawals cannot exceed total liquidity
    function maximumWithdrawal(
        uint256 claimingPower,
        uint256 totalClaimingPower,
        uint256 totalBalance
    ) internal pure returns (uint256) {
        if (claimingPower <= 0) {
            return 0;
        } else {
            return (claimingPower * totalBalance) / totalClaimingPower;
        }
    }

    /// @notice Computes the amount of wrapped token to burn from a staker
    function shareValue(
        uint256 amount,
        uint256 totalSupply,
        uint256 totalBalance
    ) internal pure returns (uint256) {
        return (totalBalance != 0 && totalSupply != 0) ? (totalSupply * amount) / totalBalance : amount;
    }

    /// @notice Computes the due time fees of a certain position
    function computeTimeFees(
        uint256 principal,
        uint256 interestRate,
        uint256 time
    ) internal pure returns (uint256 dueFees) {
        return (principal * interestRate * (time + 1)).ceilingDiv(uint32(TIME_FEE_PERIOD) * RESOLUTION);
    }

    /// @notice Computes the interest rate to apply to a position at its opening
    function computeInterestRateNoLeverage(
        uint256 netLoans,
        uint256 freeLiquidity,
        uint256 insuranceReserveBalance,
        uint256 riskFactor,
        uint256 baseFee
    ) internal pure returns (uint256) {
        uint256 uncovered = netLoans.positiveSub(insuranceReserveBalance);
        uint256 interestRate = (netLoans + uncovered) * riskFactor;
        interestRate /= (netLoans + freeLiquidity);
        interestRate += baseFee;

        return interestRate;
    }

    function calculateLockedProfit(
        uint256 profits,
        uint256 time,
        uint256 latestRepay
    ) internal pure returns (uint256) {
        return profits.positiveSub(((time - latestRepay) * profits) / DEGRADATION_COEFFICIENT);
    }
}
