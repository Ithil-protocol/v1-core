// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IYearnRegistry } from "../interfaces/external/IYearnRegistry.sol";
import { IYearnVault } from "../interfaces/external/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    YearnStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on any Yearn vault
contract YearnStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    IYearnRegistry internal immutable registry;

    constructor(
        address _vault,
        address _liquidator,
        address _registry
    ) BaseStrategy(_vault, _liquidator, "YearnStrategy", "ITHIL-YS-POS") {
        registry = IYearnRegistry(_registry);
    }

    function _openPosition(Order calldata order, bytes calldata extraParams) internal override returns (uint256) {
        address yvault = registry.latestVault(order.spentToken);
        IERC20 spentToken = IERC20(order.spentToken);
        if (yvault != order.obtainedToken) revert Strategy__Incorrect_Obtained_Token();

        if (spentToken.allowance(address(this), yvault) < order.maxSpent) spentToken.approve(yvault, type(uint256).max);

        uint256 amountIn = IYearnVault(yvault).deposit(order.maxSpent, address(this));

        return amountIn;
    }

    function _closePosition(Position memory position, uint256 maxOrMin) internal override returns (uint256, uint256) {
        // We only support native token margin (to avoid whitelisting nightmares)
        // In particular, maxOrMin is always a "min"
        IYearnVault yvault = IYearnVault(position.heldToken);

        uint256 expectedObtained = (yvault.pricePerShare() * position.allowance) /
            (10**IERC20Metadata(position.owedToken).decimals());
        uint256 maxLoss = (expectedObtained.positiveSub(maxOrMin) * 10000) / expectedObtained;

        uint256 amountIn = yvault.withdraw(position.allowance, address(vault), maxLoss);
        uint256 amountOut = position.allowance;

        return (amountIn, amountOut);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        IYearnVault yvault;

        uint256 amountOut;

        try registry.latestVault(src) returns (address vaultAddress) {
            yvault = IYearnVault(vaultAddress);
            uint256 decimals = 10**IERC20Metadata(src).decimals();
            amountOut = (amount * decimals) / yvault.pricePerShare();
        } catch {
            address vaultAddress = registry.latestVault(dst);
            yvault = IYearnVault(vaultAddress);
            uint256 decimals = 10**IERC20Metadata(dst).decimals();
            amountOut = (amount * yvault.pricePerShare()) / decimals;
        }

        return (amountOut, amountOut);
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
