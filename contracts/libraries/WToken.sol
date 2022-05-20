// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

import "./VaultMath.sol";
import "./TransferHelper.sol";

import { IWrappedToken } from "../interfaces/IWrappedToken.sol";

/// @title    WrappedToken library
/// @author   Ithil
/// @notice   A library to collect functions related to actions with wrapped tokens
library WToken {
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
