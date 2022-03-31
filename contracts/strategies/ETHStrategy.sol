// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWETH } from "../interfaces/IWETH.sol";
import { IStETH } from "../interfaces/IStETH.sol";
import { ICurve } from "../interfaces/ICurve.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    ETHStrategy contract
/// @author   Ithil
/// @notice   Stakes ETH on Lido, gets stETH, provides stETH to Curve as liquidity,
///           then stakes Curve LP tokens on Yearn.
///           Curve pool token indexes: ETH = 0, stETH = 1

contract ETHStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStETH;

    error ETHStrategy__ETH_Transfer_Failed();
    error ETHStrategy__Token_Not_Supported();
    error ETHStrategy__Not_Enough_Liquidity();

    IStETH internal immutable stETH;
    IYearnVault internal immutable yvault;
    ICurve internal immutable crvPool;
    IERC20 internal immutable crvLP;

    constructor(
        address _stETH,
        address _crvPool,
        address _crvLP,
        address _yvault,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        stETH = IStETH(_stETH);
        crvPool = ICurve(_crvPool);
        crvLP = IERC20(_crvLP);
        yvault = IYearnVault(_yvault);
    }

    function name() external pure override returns (string memory) {
        return "ETHStrategy";
    }

    receive() external payable {
        if (msg.sender != vault.WETH() && msg.sender != address(crvPool)) revert ETHStrategy__ETH_Transfer_Failed();
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        if (order.spentToken != vault.WETH()) revert ETHStrategy__Token_Not_Supported();

        IWETH weth = IWETH(vault.WETH());

        if (weth.balanceOf(address(this)) < order.maxSpent) revert ETHStrategy__Not_Enough_Liquidity();

        // Unwrap WETH to ETH
        weth.withdraw(order.maxSpent);

        // stake ETH on Lido and get stETH
        uint256 shares = stETH.submit{ value: order.maxSpent }(address(this));

        // Deposit the stETH on Curve stETH-ETH pool
        // The returned stETH amount may be lower of 1 wei, we check the correct return value using shares computation
        if (stETH.allowance(address(this), address(crvPool)) == 0) {
            stETH.safeApprove(address(crvPool), type(uint256).max);
        }
        uint256 lpTokens = crvPool.add_liquidity([uint256(0), stETH.getPooledEthByShares(shares)], order.deadline);

        // Stake crvstETH on Yearn using the Convex autocompounding stratey
        if (crvLP.allowance(address(this), address(yvault)) == 0) {
            crvLP.safeApprove(address(yvault), type(uint256).max);
        }
        amountIn = yvault.deposit(lpTokens, address(this));
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        // Unstake crvstETH from Yearn
        uint256 amount = yvault.withdraw(position.allowance, address(this), 1);

        // Remove liquidity from Curve
        uint256 minAmount = crvPool.calc_token_amount([uint256(0), amount], false); // TODO should we run it off-chain?
        amountIn = crvPool.remove_liquidity_one_coin(amount, 0, minAmount);

        // Wrap ETH to WETH
        IWETH weth = IWETH(vault.WETH());
        weth.deposit{ value: amountIn }();

        // Transfer WETH to the vault
        IERC20(address(weth)).safeTransfer(address(vault), amountIn);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        uint256 obtained = yvault.pricePerShare();
        obtained *= amount * crvPool.get_virtual_price(); // TODO check math
        return (obtained, obtained);
    }
}
