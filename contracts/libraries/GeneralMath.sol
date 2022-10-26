// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultState } from "./VaultState.sol";

/// @title    GeneralMath library
/// @author   Ithil
/// @notice   A library to perform the most common math operations
library GeneralMath {
    // Never throws, returns min(a+b,2^256-1)
    function protectedAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > type(uint256).max - b) {
            return type(uint256).max;
        } else {
            return a + b;
        }
    }

    // Never throws, returns max(a-b,0)
    function positiveSub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a - b;
        } else {
            return 0;
        }
    }

    // Throws if b = 0 and a != 0
    function ceilingDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a > 0) c = 1 + (a - 1) / b;
    }

    // Throws if c = 0 and both a != 0, b != 0
    function mulDivUp(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256) {
        return ceilingDiv(a * b, c);
    }

    // Throws if c = 0
    function mulDivDown(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256) {
        return (a * b) / c;
    }

    // Never throws, returns max(a,b)
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? b : a;
    }

    // Never throws, returns min(a,b)
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
