// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

/// @title    VaultState library
/// @author   Ithil
/// @notice   A library to stora vault state
library VaultState {
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
}
