// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library FixedPoint {
    // Fixed point number fixed to be 1e18;
    uint256 constant ONE = 1e18;

    /// @notice Fixed point multiplication when both a and b are supposed to have 18 decimals
    /// @dev approximates down to the nearest fixed point number less than a * b
    /// @dev throws if a * b >= 2^256
    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / ONE;
    }

    /// @dev approximates down to the nearest fixed point number greater than a * b
    /// @dev throws if a = 0 or b = 0
    /// @dev throws if a * b >= 2^256
    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        return 1 + (a * b - 1) / ONE;
    }

    /// @notice Fixed point division when both a and b are supposed to have 18 decimals
    /// @dev approximates down to the nearest fixed point number less than a / b
    /// @dev throws if b = 0;
    /// @dev throws if a > 2^256 / 10^18
    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * ONE) / b;
    }

    /// @notice Fixed point division when both a and b are supposed to have 18 decimals
    /// @dev approximates down to the nearest fixed point number less than a / b
    /// @dev throws if a = 0 or b = 0;
    /// @dev throws if a > 2^256 / 10^18
    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        return 1 + (a * ONE - 1) / b;
    }
}
