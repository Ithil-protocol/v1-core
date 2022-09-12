// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultMath } from "./VaultMath.sol";
import { IWrappedToken } from "../interfaces/IWrappedToken.sol";

/// @title    WrappedTokenHelper library
/// @author   Ithil
/// @notice   A library to collect functions related to actions with wrapped token
library WrappedTokenHelper {
    /// @notice mint wrapped tokens
    /// @param amount the amount of wrapped tokens to mint
    /// @param user the user to transfer wrapped tokens to
    function mintWrapped(
        IWrappedToken wToken,
        uint256 amount,
        address user
    ) internal {
        wToken.mint(user, amount);
    }

    /// @notice burns wrapped tokens from the user
    /// @param amount the amount of wrapped tokens to burn
    /// @param user the user to transfer wrapped tokens to
    function burnWrapped(
        IWrappedToken wToken,
        uint256 amount,
        address user
    ) internal {
        wToken.burn(user, amount);
    }
}
