// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title    Interface of the TokenisedVault contract
/// @author   Ithil
interface ITokenisedVault is IERC4626 {
    // Events
    event GuardianWasUpdated(address indexed guardian);
    event VaultLockWasToggled(bool indexed locked);
    event DegradationCoefficientWasChanged(uint256 degradationCoefficient);
    event Deposited(address indexed user, address indexed receiver, uint256 assets, uint256 shares);
    event Withdrawn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Borrowed(address indexed receiver, uint256 assets);
    event Repaid(address indexed repayer, uint256 amount, uint256 debt);
    event DirectMint(address indexed receiver, uint256 shares, uint256 increasedAssets);
    event DirectBurn(address indexed receiver, uint256 shares, uint256 distributedAssets);

    // Errors
    error Vault__Insufficient_Liquidity(uint256 balance);
    error Vault__Insufficient_Free_Liquidity(uint256 freeLiquidity);
    error Vault__Supply_Burned();
    error Vault__Fee_Unlock_Out_Of_Range();
    error Vault__Only_Guardian();
    error Vault__Locked();
}
