// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { MockYearnVault } from "./MockYearnVault.sol";

contract MockYearnRegistry is IYearnRegistry, Ownable {
    mapping(address => address) public yvaults;
    uint256 public priceForShare = 0;

    event SharePriceWasChanged(uint256 indexed oldPrice, uint256 indexed newPrice);

    modifier vaultExists(address token) {
        require(yvaults[token] != address(0), "MockYearnRegistry: Unsupported token");
        _;
    }

    function latestVault(address token) external view override vaultExists(token) returns (address) {
        return yvaults[token];
    }

    function newVault(address token) external override onlyOwner returns (address) {
        yvaults[token] = address(new MockYearnVault(token));

        return yvaults[token];
    }

    function setSharePrice(uint256 newPrice) external onlyOwner {
        emit SharePriceWasChanged(priceForShare, newPrice);

        priceForShare = newPrice;
    }
}
