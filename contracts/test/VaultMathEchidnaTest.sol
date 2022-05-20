// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;
pragma experimental ABIEncoderV2;

import { VaultMath } from "../libraries/VaultMath.sol";

contract VaultMathEchidnaTest {
    function echidnaMaximumWithdraw() external pure returns (bool) {
        return VaultMath.maximumWithdrawal(0, 0, 0) == 0;
    }
}
