// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

/// @title  Implements smart contract versioning
interface IVersioned {
    struct Version {
        uint16 major;
        uint16 minor;
        uint16 patch;
    }

    /// @return The version of the contract.
    function version() external view returns (Version memory);
}
