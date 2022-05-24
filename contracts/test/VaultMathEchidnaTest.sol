// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { VaultMath } from "../libraries/VaultMath.sol";

/// @dev Used for testing, unaudited
contract VaultMathEchidnaTest {
    function echidnaMaximumWithdraw() external pure returns (bool) {
        return VaultMath.maximumWithdrawal(0, 0, 0) == 0;
    }
}
