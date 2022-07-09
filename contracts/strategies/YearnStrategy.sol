// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYearnRegistry } from "../interfaces/external/IYearnRegistry.sol";
import { IYearnVault } from "../interfaces/external/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    YearnStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on any Yearn vault
contract YearnStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IYearnRegistry internal immutable registry;

    constructor(
        address _vault,
        address _liquidator,
        address _registry
    ) BaseStrategy(_vault, _liquidator, "YearnStrategy", "ITHIL-YS-POS") {
        registry = IYearnRegistry(_registry);
    }

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        address yvault = registry.latestVault(order.spentToken);
        if (yvault != order.obtainedToken) revert Strategy__Incorrect_Obtained_Token();

        super._maxApprove(IERC20(order.spentToken), yvault);

        amountIn = IYearnVault(yvault).deposit(order.maxSpent, address(this));
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        IYearnVault yvault = IYearnVault(position.heldToken);
        amountIn = yvault.withdraw(position.allowance, address(vault), expectedCost);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        address vaultAddress = registry.latestVault(src);
        IYearnVault yvault = IYearnVault(vaultAddress);

        uint256 obtained = yvault.pricePerShare();
        obtained *= amount;
        return (obtained, obtained);
    }
}
