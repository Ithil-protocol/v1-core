// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

import { VaultState } from "./VaultState.sol";

/// @title    GeneralMath library
/// @author   Ithil
/// @notice   A library to perform the most common operations
library GeneralMath {
    function positiveSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a > b) c = a - b;
    }
}
