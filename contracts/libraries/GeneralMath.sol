// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { VaultState } from "./VaultState.sol";

/// @title    GeneralMath library
/// @author   Ithil
/// @notice   A library to perform the most common operations
library GeneralMath {
    function positiveSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a > b) c = a - b;
    }

    function subtractLoan(VaultState.VaultData storage self, uint256 b) internal {
        if (self.netLoans > b) self.netLoans -= b;
        else self.netLoans = 0;
    }

    function subtractInsuranceReserve(VaultState.VaultData storage self, uint256 b) internal {
        if (self.insuranceReserveBalance > b) self.insuranceReserveBalance -= b;
        else self.insuranceReserveBalance = 0;
    }
}
