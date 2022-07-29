// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Vault } from "../../Vault.sol";
import { MockToken } from "../../mock/MockToken.sol";

/// @dev Used for testing, unaudited
contract MockTokenTest is MockToken {
    constructor() MockToken("test", "TST", 18) {}

    function echidna_test_staking() public view returns (bool) {
        return balanceOf(address(this)) > 0;
    }
}
