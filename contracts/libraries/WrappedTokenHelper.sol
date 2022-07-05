// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultMath } from "./VaultMath.sol";
import { IWrappedToken } from "../interfaces/IWrappedToken.sol";

/// @title    WrappedTokenHelper library
/// @author   Ithil
/// @notice   A library to collect functions related to actions with wrapped token
/// @dev      To be replaced by EIP4626 when the standard is mature enough
library WrappedTokenHelper {
    function mintWrapped(
        IWrappedToken wToken,
        uint256 amount,
        address user,
        uint256 totalWealth
    ) internal returns (uint256 toMint) {
        toMint = VaultMath.shareValue(amount, wToken.totalSupply(), totalWealth);
        wToken.mint(user, toMint);
    }

    function burnWrapped(
        IWrappedToken wToken,
        uint256 amount,
        uint256 totalWealth,
        address user
    ) internal returns (uint256 toBurn) {
        uint256 totalClaims = wToken.totalSupply();

        toBurn = VaultMath.shareValue(amount, totalClaims, totalWealth);
        wToken.burn(user, toBurn);
    }
}
