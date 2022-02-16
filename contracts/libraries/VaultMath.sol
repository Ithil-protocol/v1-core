// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

/// @title    VaultMath library
/// @author   Ithil
/// @notice   A library to calculate vault-related stuff, like APY, lending interests, max withdrawable tokens
library VaultMath {
    uint24 internal constant RESOLUTION = 10000;
    uint24 internal constant TIME_FEE_PERIOD = 86400;
    uint40 internal constant APY_PERIOD = 31536000;
    uint24 internal constant MAX_RATE = 10000; //todo: adjust
    uint24 internal constant RESERVE_RATIO = 2500; //todo: adjust

    /// @notice Computes the maximum amount of money an investor can withdraw from the pool
    /// @dev Floor(x+y) >= Floor(x) + Floor(y), therefore the sum of all investors'
    /// withdrawals cannot exceed total liquidity
    function maximumWithdrawal(
        uint256 claimingPower,
        uint256 totalClaimingPower,
        uint256 totalBalance
    ) internal pure returns (uint256 maxWithdraw) {
        if (claimingPower <= 0) {
            maxWithdraw = 0;
        } else {
            maxWithdraw = (claimingPower * totalBalance) / totalClaimingPower;
        }
    }

    /// @notice Computes the claiming power of an investor after a deposit
    function claimingPowerAfterDeposit(
        uint256 deposit,
        uint256 oldClaimingPower,
        uint256 totalClaimingPower,
        uint256 totalBalance
    ) internal pure returns (uint256 newClaimingPower) {
        if (deposit <= 0) {
            newClaimingPower = oldClaimingPower;
        } else if (totalBalance <= 0) {
            newClaimingPower = deposit;
        } else {
            newClaimingPower = oldClaimingPower + (totalClaimingPower * deposit) / totalBalance;
        }
    }

    /// @notice Computes the claiming power of an investor after a withdrawal
    function claimingPowerAfterWithdrawal(
        uint256 withdrawal,
        uint256 oldClaimingPower,
        uint256 totalClaimingPower,
        uint256 totalBalance
    ) internal pure returns (uint256 newClaimingPower) {
        if (withdrawal >= maximumWithdrawal(oldClaimingPower, totalClaimingPower, totalBalance)) {
            newClaimingPower = 0;
        } else {
            newClaimingPower = oldClaimingPower - (totalClaimingPower * withdrawal) / totalBalance;
        }
    }

    function computeFees(uint256 amount, uint256 fixedFee) internal pure returns (uint256 debt) {
        return (amount * fixedFee) / RESOLUTION;
    }

    function computeTimeFees(
        uint256 principal,
        uint256 interestRate,
        uint256 time
    ) internal pure returns (uint256 dueFees) {
        return (principal * interestRate * time) / (uint32(TIME_FEE_PERIOD) * RESOLUTION);
    }

    /// @notice Computes the interest rate to apply to a position at its opening
    /// @param baseFee fees for token1
    /// @param riskFactor fees for token2
    /// @param tradeAmount always in the same token as the considered vault
    /// @param collateral the collateral placed for the loan, always in the same token as the considered vault
    /// @param freeLiquidity the liquidity available for borrowing
    /// @param insuranceBalance the insured balance
    function computeInterestRate(
        uint256 baseFee,
        uint256 riskFactor,
        uint256 tradeAmount,
        uint256 collateral,
        uint256 freeLiquidity,
        uint256 insuranceBalance
    ) internal pure returns (uint256 interestRate) {
        assert(freeLiquidity > 0);
        // tradeAmount is covered by insurance balance,
        // thus the uncovered balance is liquidity - (insurance - tradeAmount)
        uint256 uncoveredBalance = 0;
        if (freeLiquidity + tradeAmount >= insuranceBalance)
            uncoveredBalance = freeLiquidity + tradeAmount - insuranceBalance;
        interestRate =
            ((baseFee + riskFactor) * uncoveredBalance * tradeAmount) /
            (freeLiquidity * collateral * RESOLUTION);
    }
}
