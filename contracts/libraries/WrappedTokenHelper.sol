// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultMath } from "./VaultMath.sol";
import { IWrappedToken } from "../interfaces/IWrappedToken.sol";

/// @title    WrappedTokenHelper library
/// @author   Ithil
/// @notice   A library to collect functions related to actions with wrapped token
library WrappedTokenHelper {
    function mintWrapped(
        IWrappedToken wToken,
        uint256 amount,
        address user,
        uint256 totalWealth
    ) internal returns (uint256) {
        uint256 toMint = VaultMath.shareValue(amount, wToken.totalSupply(), totalWealth);
        wToken.mint(user, toMint);

        return toMint;
    }

    function burnWrapped(
        IWrappedToken wToken,
        uint256 amount,
        uint256 totalWealth,
        address user
    ) internal returns (uint256) {
        uint256 toBurn = VaultMath.shareValue(amount, wToken.totalSupply(), totalWealth);
        wToken.burn(user, toBurn);

        return toBurn;
    }
}
