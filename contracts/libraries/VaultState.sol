// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import "./VaultMath.sol";
import "./TransferHelper.sol";

/// @title    VaultState library
/// @author   Ithil
/// @notice   A library to stora vault state
library VaultState {
    using TransferHelper for IERC20;
    using GeneralMath for uint256;

    error Vault__Insufficient_Funds_Available(address token, uint256 requested);
    error Vault__Repay_Failed();

    /// @notice store data about whitelisted tokens
    /// @param supported Easily check if a token is supported or not (null VaultData struct)
    /// @param locked Whether the token is locked - can only be withdrawn
    /// @param wrappedToken Address of the corresponding iToken
    /// @param creationTime block timestamp of the subvault and relative iToken creation
    /// @param baseFee
    /// @param fixedFee
    /// @param netLoans Total amount of liquidity currently lent to traders
    /// @param insuranceReserveBalance Total amount of liquidity left as insurance
    /// @param optimalRatio The optimal ratio of the insurance reserve
    /// @param treasuryLiquidity The amount of liquidity owned by the treasury
    struct VaultData {
        bool supported;
        bool locked;
        address wrappedToken;
        uint256 creationTime;
        uint256 baseFee;
        uint256 fixedFee;
        uint256 netLoans;
        uint256 insuranceReserveBalance;
        uint256 optimalRatio;
        uint256 treasuryLiquidity;
    }

    function addInsuranceReserve(
        VaultState.VaultData storage self,
        uint256 totalBalance,
        uint256 fees
    ) internal {
        uint256 availableInsuranceBalance = self.insuranceReserveBalance.positiveSub(self.netLoans);

        self.insuranceReserveBalance +=
            (fees * self.optimalRatio * (totalBalance - availableInsuranceBalance)) /
            (totalBalance * VaultMath.RESOLUTION);
    }

    function takeLoan(
        VaultState.VaultData storage self,
        IERC20 token,
        uint256 amount,
        uint256 riskFactor
    ) internal returns (uint256 freeLiquidity, uint256 received) {
        uint256 totalRisk = self.optimalRatio * self.netLoans;
        self.netLoans += amount;
        self.optimalRatio = (totalRisk + amount * riskFactor) / self.netLoans;

        freeLiquidity = IERC20(token).balanceOf(address(this)) - self.insuranceReserveBalance;

        if (amount > freeLiquidity) revert Vault__Insufficient_Funds_Available(address(token), amount);

        received = token.sendTokens(msg.sender, amount);
    }

    function subtractLoan(VaultState.VaultData storage self, uint256 b) private {
        if (self.netLoans > b) self.netLoans -= b;
        else self.netLoans = 0;
    }

    function subtractInsuranceReserve(VaultState.VaultData storage self, uint256 b) private {
        if (self.insuranceReserveBalance > b) self.insuranceReserveBalance -= b;
        else self.insuranceReserveBalance = 0;
    }

    function addTreasuryLiquidity(
        VaultState.VaultData storage self,
        IERC20 token,
        uint256 amount
    ) internal {
        (, amount) = token.transferTokens(msg.sender, address(this), amount);
        self.treasuryLiquidity += amount;
    }

    function repayLoan(
        VaultState.VaultData storage self,
        IERC20 token,
        address borrower,
        uint256 debt,
        uint256 fees,
        uint256 amount,
        uint256 riskFactor
    ) internal {
        uint256 totalRisk = self.optimalRatio * self.netLoans;
        subtractLoan(self, debt);
        self.optimalRatio = self.netLoans != 0 ? totalRisk.positiveSub(riskFactor * debt) / self.netLoans : 0;

        if (amount >= debt + fees) {
            addInsuranceReserve(self, token.balanceOf(address(this)), fees);

            if (!token.transfer(borrower, amount - debt - fees)) revert Vault__Repay_Failed();
        } else if (amount < debt) subtractInsuranceReserve(self, debt - amount);
    }
}
