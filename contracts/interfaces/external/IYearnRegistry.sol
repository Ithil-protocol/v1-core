// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

/// @title    Interface of the Yearn Registry contract
interface IYearnRegistry {
    /**
     * @notice Get the address of the latest deployed yvault for a specific token
     * @dev If no yvault is found, it will revert
     * @param token The underlying token
     * @return yvault The linked vault
     */
    function latestVault(address token) external view returns (address);

    function newVault(address token) external returns (address);
}
