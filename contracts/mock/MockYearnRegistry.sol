// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnPartnerTracker } from "../interfaces/IYearnPartnerTracker.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { MockYearnVault } from "./MockYearnVault.sol";

contract MockYearnRegistry is IYearnRegistry, IYearnPartnerTracker, Ownable {
    using SafeERC20 for IERC20;

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

    function deposit(
        address vault,
        address partnerId,
        uint256 amount
    ) external override returns (uint256) {
        IYearnVault yault = IYearnVault(vault);
        IERC20 token = IERC20(yault.token());
        if (token.allowance(address(this), vault) < amount) {
            token.safeApprove(vault, 0);
            token.safeApprove(vault, type(uint256).max);
        }
        token.safeTransferFrom(msg.sender, address(this), amount);

        return yault.deposit(amount, msg.sender);
    }
}
