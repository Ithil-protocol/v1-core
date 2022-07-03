// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    YearnStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on any Yearn vault
contract YearnStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error YearnStrategy__Restricted_Access(address owner, address sender);
    error YearnStrategy__Not_Enough_Liquidity(uint256 balance, uint256 spent);
    error YearnStrategy__Unsupported_Vault(address token);

    IYearnRegistry internal immutable registry;
    mapping(address => address) public yvaults;

    constructor(
        address _vault,
        address _liquidator,
        address _registry
    ) BaseStrategy(_vault, _liquidator, "YearnStrategy", "ITHIL-YS-POS") {
        registry = IYearnRegistry(_registry);
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        IERC20 tkn = IERC20(order.spentToken);
        uint256 balance = tkn.balanceOf(address(this));
        if (balance < order.maxSpent) revert YearnStrategy__Not_Enough_Liquidity(balance, order.maxSpent);

        if (yvaults[order.spentToken] == address(0)) revert YearnStrategy__Unsupported_Vault(order.spentToken);

        amountIn = IYearnVault(yvaults[order.spentToken]).deposit(order.maxSpent, address(this));
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
        address vaultAddress = registry.latestVault(src);
        IYearnVault yvault = IYearnVault(vaultAddress);

        uint256 obtained = yvault.pricePerShare();
        obtained *= amount;
        return (obtained, obtained);
    }

    // @todo emit events?
    function addYVault(address token) external onlyOwner {
        address yvault = registry.latestVault(token);
        yvaults[token] = yvault;

        super._maxApprove(IERC20(token), yvault);
    }

    function removeYVault(address token) external onlyOwner {
        delete yvaults[token];

        //super._maxApprove(IERC20(token), yvault); // @todo remove approval
    }
}
