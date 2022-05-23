// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWETH } from "../interfaces/IWETH.sol";
import { IStETH } from "../interfaces/IStETH.sol";
import { ICurve } from "../interfaces/ICurve.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnPartnerTracker } from "../interfaces/IYearnPartnerTracker.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    LidoStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged staking on Lido
/// @dev      Stakes ETH on Lido, gets stETH, provides stETH to Curve as liquidity,
///           then stakes Curve LP tokens on Yearn.
///           Curve pool token indexes: ETH = 0, stETH = 1
contract LidoStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStETH;

    error LidoStrategy__ETH_Transfer_Failed();
    error LidoStrategy__Token_Not_Supported();
    error LidoStrategy__Not_Enough_Liquidity();

    IStETH internal immutable stETH;
    ICurve internal immutable crvPool;
    IERC20 internal immutable crvLP;
    IYearnVault internal immutable yvault;
    IYearnPartnerTracker internal immutable yearnPartnerTracker;
    address internal immutable partnerId;

    constructor(
        address _vault,
        address _liquidator,
        address _stETH,
        address _crvPool,
        address _crvLP,
        address _registry,
        address _partnerId,
        address _yearnPartnerTracker
    ) BaseStrategy(_vault, _liquidator) {
        stETH = IStETH(_stETH);
        crvPool = ICurve(_crvPool);
        crvLP = IERC20(_crvLP);
        partnerId = _partnerId;
        yearnPartnerTracker = IYearnPartnerTracker(_yearnPartnerTracker);

        yvault = IYearnVault(IYearnRegistry(_registry).latestVault(_crvLP));
        stETH.safeApprove(_crvPool, type(uint256).max);
        crvLP.safeApprove(_yearnPartnerTracker, type(uint256).max);
    }

    function name() external pure override returns (string memory) {
        return "LidoStrategy";
    }

    receive() external payable {
        if (msg.sender != vault.weth() && msg.sender != address(crvPool)) revert LidoStrategy__ETH_Transfer_Failed();
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        if (order.spentToken != vault.weth()) revert LidoStrategy__Token_Not_Supported();

        IWETH weth = IWETH(vault.weth());

        if (weth.balanceOf(address(this)) < order.maxSpent) revert LidoStrategy__Not_Enough_Liquidity();

        // Unwrap WETH to ETH
        weth.withdraw(order.maxSpent);

        // stake ETH on Lido and get stETH
        uint256 shares = stETH.submit{ value: order.maxSpent }(address(this));

        // Deposit the stETH on Curve stETH-ETH pool
        // The returned stETH amount may be lower of 1 wei, we check the correct return value using shares computation
        uint256 lpTokens = crvPool.add_liquidity([uint256(0), stETH.getPooledEthByShares(shares)], order.deadline);

        // Stake crvstETH on Yearn using the Convex autocompounding stratey
        amountIn = yearnPartnerTracker.deposit(address(yvault), partnerId, lpTokens);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        // Unstake crvstETH from Yearn
        uint256 pricePerShare = yvault.pricePerShare();
        uint256 maxLoss = ((position.allowance * pricePerShare - expectedCost) * 10000) /
            (position.allowance * pricePerShare);
        uint256 amount = yvault.withdraw(position.allowance, address(this), maxLoss);

        // Remove liquidity from Curve
        uint256 minAmount = crvPool.calc_token_amount([uint256(0), amount], false); // TODO should we run it off-chain?
        amountIn = crvPool.remove_liquidity_one_coin(amount, 0, minAmount);

        // Wrap ETH to WETH
        IWETH weth = IWETH(vault.weth());
        weth.deposit{ value: amountIn }();

        // Transfer WETH to the vault
        IERC20(address(weth)).safeTransfer(address(vault), amountIn);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        uint256 obtained;
        if (dst != vault.weth()) obtained = (amount * 10**36) / (crvPool.get_virtual_price() * yvault.pricePerShare());
        else obtained = (amount * crvPool.get_virtual_price() * yvault.pricePerShare()) / (10**36);
        return (obtained, obtained);
    }
}
