// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import "./VaultMath.sol";
import "./TransferHelper.sol";

/// @title    VaultState library
/// @author   Ithil
/// @notice   A library to stora vault state
library VaultState {
    using TransferHelper for IERC20;

    error Vault__Insufficient_Funds_Available(address token, uint256 requested);

    /// @notice store data about whitelisted tokens
    /// @param supported Easily check if a token is supported or not (null VaultData struct)
    /// @param locked Whether the token is locked - can only be withdrawn
    /// @param wrappedToken Address of the corresponding iToken
    /// @param creationTime block timestamp of the subvault and relative iToken creation
    /// @param baseFee
    /// @param fixedFee
    /// @param netLoans Total amount of liquidity currently lent to traders
    /// @param insuranceReserveBalance Total amount of liquidity left as insurance
    struct VaultData {
        bool supported;
        bool locked;
        address wrappedToken;
        uint256 creationTime;
        uint256 baseFee;
        uint256 fixedFee;
        uint256 netLoans;
        uint256 insuranceReserveBalance;
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

    function takeLoan(
        VaultState.VaultData storage self,
        IERC20 token,
        uint256 amount
    ) internal returns (uint256 freeLiquidity, uint256 received) {
        self.netLoans += amount;

        freeLiquidity = IERC20(token).balanceOf(address(this)) - self.insuranceReserveBalance;

        if (amount > freeLiquidity) revert Vault__Insufficient_Funds_Available(address(token), amount);

        received = token.sendTokens(msg.sender, amount);
    }

    function subtractLoan(VaultState.VaultData storage self, uint256 b) internal {
        if (self.netLoans > b) self.netLoans -= b;
        else self.netLoans = 0;
    }

    function subtractInsuranceReserve(VaultState.VaultData storage self, uint256 b) internal {
        if (self.insuranceReserveBalance > b) self.insuranceReserveBalance -= b;
        else self.insuranceReserveBalance = 0;
    }
}
