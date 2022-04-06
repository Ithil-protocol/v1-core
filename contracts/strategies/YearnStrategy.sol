// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

contract YearnStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error YearnStrategy__Restricted_Access();
    error YearnStrategy__Inexistent_Pool(address);
    error YearnStrategy__Not_Enough_Liquidity();

    IYearnRegistry internal immutable registry;

    constructor(
        address _registry,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        registry = IYearnRegistry(_registry);
    }

    function name() external pure override returns (string memory) {
        return "YearnStrategy";
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        IERC20 tkn = IERC20(order.spentToken);

        if (tkn.balanceOf(address(this)) < order.maxSpent) revert YearnStrategy__Not_Enough_Liquidity();

        (bool success, bytes memory return_data) = address(registry).call( // This creates a low level call to the token
            abi.encodePacked( // This encodes the function to call and the parameters to pass to that function
                registry.latestVault.selector, // This is the function identifier of the function we want to call
                abi.encode(order.spentToken) // This encodes the parameter we want to pass to the function
            )
        );

        if (!success) revert YearnStrategy__Inexistent_Pool(order.spentToken);

        address vaultAddress = abi.decode(return_data, (address));
        IYearnVault yvault = IYearnVault(vaultAddress);

        super._maxApprove(tkn, vaultAddress);

        amountIn = yvault.deposit(order.maxSpent, address(this));
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        (bool success, bytes memory return_data) = address(registry).call(
            abi.encodePacked(registry.latestVault.selector, abi.encode(position.owedToken))
        );

        if (!success) revert YearnStrategy__Inexistent_Pool(position.owedToken);

        address yvault = abi.decode(return_data, (address));
        uint256 pricePerShare = IYearnVault(yvault).pricePerShare();
        uint256 maxLoss = ((position.allowance * pricePerShare - expectedCost) * 10000) /
            (position.allowance * pricePerShare);

        amountIn = IYearnVault(yvault).withdraw(position.allowance, address(vault), maxLoss);
        /// @todo check maxLoss=1 (0.01%) parameter
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
