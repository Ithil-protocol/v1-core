// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the SVGImageGenerator contract
/// @author   Ithil
interface ISVGImageGenerator {
    function generateMetadata(
        string memory name,
        string memory symbol,
        uint256 id,
        address token,
        uint256 amount,
        uint256 createdAt,
        int256 score
    ) external pure returns (string memory);
}
