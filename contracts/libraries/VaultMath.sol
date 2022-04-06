// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { VaultState } from "./VaultState.sol";
import { GeneralMath } from "./GeneralMath.sol";

/// @title    VaultMath library
/// @author   Ithil
/// @notice   A library to calculate vault-related stuff, like APY, lending interests, max withdrawable tokens
library VaultMath {
    using GeneralMath for uint256;

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
    /// @param data the data containing the current vault state
    /// @param freeLiquidity the free liquidity of the vault
    /// @param riskFactor the riskiness of the investment
    function computeInterestRateNoLeverage(
        VaultState.VaultData memory data,
        uint256 freeLiquidity,
        uint256 riskFactor
    ) internal pure returns (uint256 interestRate) {
        uint256 uncovered = data.netLoans.positiveSub(data.insuranceReserveBalance);
        interestRate = (data.netLoans + uncovered) * riskFactor;
        interestRate /= (data.netLoans + freeLiquidity);
        interestRate += data.baseFee;
    }

    function subtractLoan(VaultState.VaultData storage self, uint256 b) internal returns (uint256) {
        if (self.netLoans > b) self.netLoans -= b;
        else self.netLoans = 0;
        return self.netLoans;
    }

    function subtractInsuranceReserve(VaultState.VaultData storage self, uint256 b) internal {
        if (self.insuranceReserveBalance > b) self.insuranceReserveBalance -= b;
        else self.insuranceReserveBalance = 0;
    }

    function addInsuranceReserve(
        VaultState.VaultData storage self,
        uint256 totalBalance,
        uint256 insReserveBalance,
        uint256 fees
    ) internal {
        self.insuranceReserveBalance +=
            (fees * VaultMath.RESERVE_RATIO * (totalBalance - insReserveBalance)) /
            (totalBalance * VaultMath.RESOLUTION);
    }
}
