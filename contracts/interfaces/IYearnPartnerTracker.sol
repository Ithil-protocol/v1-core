// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

/// @title    Interface of the Yearn PartnerTracker contract
/// @author   Yearn finance
interface IYearnPartnerTracker {
    /**
     * @notice Deposit into a vault the specified amount from depositer
     * @param vault The address of the vault
     * @param partnerId The address of the partner who has referred this deposit
     * @param amount The amount to deposit
     * @return The number of yVault tokens received
     */
    function deposit(
        address vault,
        address partnerId,
        uint256 amount
    ) external returns (uint256);
}
