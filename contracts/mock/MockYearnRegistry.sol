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
    mapping(address => uint256) public pricePerShare;

    event SharePriceWasUpdated(address indexed token, uint256 oldPrice, uint256 newPrice);

    modifier vaultExists(address token) {
        require(yvaults[token] != address(0), "MockYearnRegistry: Unsupported token");
        _;
    }

    function latestVault(address token) external view override vaultExists(token) returns (address) {
        return yvaults[token];
    }

    function newVault(address token) external override onlyOwner returns (address) {
        yvaults[token] = address(new MockYearnVault(token));
        pricePerShare[token] = 1;

        return yvaults[token];
    }

    function setSharePrice(address token, uint256 newPrice) external onlyOwner {
        emit SharePriceWasUpdated(token, pricePerShare[token], newPrice);

        pricePerShare[token] = newPrice;
    }
}
