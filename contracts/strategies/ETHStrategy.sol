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
        address _yvault,
        address _crvPool,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        stETH = IStETH(_stETH);
        yvault = IYearnVault(_yvault);
        crvPool = ICurve(_crvPool);
    }

    function name() external pure override returns (string memory) {
        return "ETHStrategy";
    }

    receive() external payable {
        if (msg.sender != vault.WETH()) revert ETHStrategy__ETH_Transfer_Failed();
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        if (order.spentToken != vault.WETH()) revert ETHStrategy__Token_Not_Supported();

        IWETH weth = IWETH(vault.WETH());
        uint256 amount = borrowed + collateralReceived;

        if (weth.balanceOf(address(this)) < amount) revert ETHStrategy__Not_Enough_Liquidity();

        // Unwrap WETH to ETH
        weth.withdraw(amount);

        // stake ETH on Lido and get stETH
        uint256 stETHAmount = stETH.submit{ value: amount }(address(this));

        // Deposit the stETH on Curve stETH-ETH pool
        if (stETH.allowance(address(this), address(crvPool)) == 0) {
            stETH.safeApprove(address(crvPool), type(uint256).max);
        }
        uint256 lpTokens = crvPool.add_liquidity([uint256(0), uint256(1)], stETHAmount);

        // Stake crvstETH on Yearn using the Convex autocompounding stratey
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
        crvPool.remove_liquidity(amount, [uint256(0), uint256(0)]);

        // Swap stETH to ETH
        amountIn = crvPool.exchange(0, int128(int256(amount)), 0, 0);

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
