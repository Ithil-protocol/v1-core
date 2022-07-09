// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IYearnRegistry } from "../interfaces/external/IYearnRegistry.sol";
import { IYearnVault } from "../interfaces/external/IYearnVault.sol";
import { MockYearnVault } from "./MockYearnVault.sol";

/// @dev Used for testing, unaudited
contract MockYearnRegistry is IYearnRegistry, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => address) public yvaults;
    uint256 public priceForShare = 0;

    event SharePriceWasUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);

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
        emit SharePriceWasUpdated(priceForShare, newPrice);

        priceForShare = newPrice;
    }
}
