// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/// @title    Interface of WrappedToken contract
/// @author   Ithil
interface IWrappedToken is IERC20, IERC20Permit {
    /// @notice Creates and sends tokens to a user
    /// @param user The user to send tokens to
    /// @param amount The amount of tokens to mint
    function mint(address user, uint256 amount) external;

    /// @notice Burns tokens from a user
    /// @param user The user to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address user, uint256 amount) external;

    /// @notice The number of decimals of the token
    /// @return The token decimals
    function decimals() external view returns (uint8);
}
