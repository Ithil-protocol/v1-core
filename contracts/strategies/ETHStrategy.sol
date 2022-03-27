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
import "hardhat/console.sol";

contract ETHStrategy is BaseStrategy {
    using SafeERC20 for IStETH;

    error ETHStrategy__ETH_Transfer_Failed();
    error ETHStrategy__Token_Not_Supported();
    error ETHStrategy__Not_Enough_Liquidity();

    IStETH internal immutable stETH;
    IYearnVault internal immutable yvault;
    ICurve internal immutable crvPool;

    constructor(
        address _stETH,
        address _crvPool,
        address _yvault,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        stETH = IStETH(_stETH);
        crvPool = ICurve(_crvPool);
        yvault = IYearnVault(_yvault);
    }

    function name() external pure override returns (string memory) {
        return "ETHStrategy";
    }

    receive() external payable {
        if (msg.sender != vault.WETH()) revert ETHStrategy__ETH_Transfer_Failed();
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        if (order.spentToken != vault.WETH()) revert ETHStrategy__Token_Not_Supported();

        IWETH weth = IWETH(vault.WETH());

        if (weth.balanceOf(address(this)) < order.maxSpent) revert ETHStrategy__Not_Enough_Liquidity();

        // Unwrap WETH to ETH
        weth.withdraw(order.maxSpent);

        console.log("maxSpent", order.maxSpent);

        // stake ETH on Lido and get stETH
        stETH.submit{ value: order.maxSpent }(address(this));

        // Deposit the stETH on Curve stETH-ETH pool
        if (stETH.allowance(address(this), address(crvPool)) == 0) {
            stETH.safeApprove(address(crvPool), type(uint256).max);
        }

        console.log("stETH tokens before", IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84).balanceOf(address(this)));

        // The returned stETH amount may be lower of 1 wei, we correct it here
        uint256 amount = stETH.balanceOf(address(this)); // we could do order.maxSpent - 1 and risk having spare 1 weis
        uint256 lpTokens = crvPool.add_liquidity([uint256(0), amount], order.deadline); // TODO correct the zero with the slippage (min out?)

        console.log("stETH tokens after", IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84).balanceOf(address(this)));
        console.log("Curve LP tokens", IERC20(0xdCD90C7f6324cfa40d7169ef80b12031770B4325).balanceOf(address(this)));
        console.log("lpTokens", lpTokens);

        // Stake crvstETH on Yearn using the Convex autocompounding stratey
        amountIn = yvault.deposit(lpTokens, address(this)); // TODO it fails here
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        console.log("hello");

        // Unstake crvstETH from Yearn
        uint256 amount = yvault.withdraw(position.allowance, address(this), 1);

        console.log("amount", amount);

        // Remove liquidity from Curve
        crvPool.remove_liquidity(amount, [uint256(0), uint256(0)]);

        // Swap stETH to ETH
        amountIn = crvPool.exchange(0, int128(int256(amount)), 0, 0);

        console.log("amountIn", amountIn);

        // Wrap ETH to WETH
        IWETH weth = IWETH(vault.WETH());
        weth.deposit{ value: amountIn }();
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
