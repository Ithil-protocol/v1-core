// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnPartnerTracker } from "../interfaces/IYearnPartnerTracker.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

import "hardhat/console.sol";

contract YearnStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error YearnStrategy__Restricted_Access();
    error YearnStrategy__Inexistent_Pool(address token);
    error YearnStrategy__Not_Enough_Liquidity(uint256 maxSpent);

    IYearnRegistry internal immutable registry;
    address internal immutable yearnPartnerTracker;
    address internal immutable partnerId;

    constructor(
        address _registry,
        address _vault,
        address _liquidator,
        address _partnerId,
        address _yearnPartnerTracker
    ) BaseStrategy(_vault, _liquidator) {
        registry = IYearnRegistry(_registry);
        partnerId = _partnerId;
        yearnPartnerTracker = _yearnPartnerTracker;
    }

    function name() external pure override returns (string memory) {
        return "YearnStrategy";
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        IERC20 tkn = IERC20(order.spentToken);

        if (tkn.balanceOf(address(this)) < order.maxSpent) revert YearnStrategy__Not_Enough_Liquidity(order.maxSpent);

        address vaultAddress = registry.latestVault(order.spentToken);
        super._maxApprove(tkn, yearnPartnerTracker);

        amountIn = IYearnPartnerTracker(yearnPartnerTracker).deposit(vaultAddress, partnerId, order.maxSpent);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        address vaultAddress = registry.latestVault(position.owedToken);
        IYearnVault yvault = IYearnVault(vaultAddress);

        uint256 pricePerShare = yvault.pricePerShare();
        uint256 maxLoss = ((position.allowance * pricePerShare - expectedCost) * 10000) /
            (position.allowance * pricePerShare);

        amountIn = yvault.withdraw(position.allowance, address(vault), maxLoss);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        (bool success, bytes memory return_data) = address(registry).staticcall(
            abi.encodePacked(registry.latestVault.selector, abi.encode(src))
        );

        if (!success) revert YearnStrategy__Inexistent_Pool(src);

        address vaultAddress = abi.decode(return_data, (address));
        IYearnVault yvault = IYearnVault(vaultAddress);

        uint256 obtained = yvault.pricePerShare();
        obtained *= amount;
        return (obtained, obtained);
    }
}
