// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWETH } from "../interfaces/IWETH.sol";
import { IStETH } from "../interfaces/IStETH.sol";
import { IConvex } from "../interfaces/IConvex.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import "hardhat/console.sol";

contract ETHStrategy is BaseStrategy {
    using SafeERC20 for IStETH;

    error ETHStrategy__ETH_Transfer_Failed();
    error ETHStrategy__Token_Not_Supported();
    error ETHStrategy__Not_Enough_Liquidity();
    error ETHStrategy__Generic_Error();

    IStETH internal immutable stETH;
    IConvex internal immutable convex;
    uint24 internal immutable pid;

    constructor(
        address _stETH,
        address _convex,
        uint24 _pid,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        stETH = IStETH(_stETH);
        convex = IConvex(_convex);
        pid = _pid;
    }

    function name() external pure override returns (string memory) {
        return "ETHStrategy";
    }

    receive() external payable {
        console.log("Receiving...");
        if (msg.sender != vault.WETH()) revert ETHStrategy__ETH_Transfer_Failed();
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        if (order.spentToken != vault.WETH()) revert ETHStrategy__Token_Not_Supported();
        IWETH weth = IWETH(order.spentToken);
        uint256 amount = borrowed + collateralReceived;

        if (weth.balanceOf(address(this)) < amount) revert ETHStrategy__Not_Enough_Liquidity();

        // Unwrap WETH to ETH
        weth.withdraw(amount);

        // stake ETH on Lido and get stETH
        uint256 stETHAmount = stETH.submit{ value: amount }(address(this));

        if (stETH.allowance(address(this), address(convex)) == 0) {
            stETH.safeApprove(address(convex), type(uint256).max);
        }

        // Stake stETH on Curve via Convex
        bool success = convex.deposit(pid, stETHAmount, true);
        if (!success) revert ETHStrategy__Generic_Error();
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        bool success = convex.withdraw(pid, position.allowance);
        if (!success) revert ETHStrategy__Generic_Error();

        // Wrap ETH to WETH
        IWETH weth = IWETH(vault.WETH());
        weth.deposit{ value: position.allowance }();

        /*
        (bool success, bytes memory return_data) = address(registry).call(
            abi.encodePacked(registry.latestVault.selector, abi.encode(position.owedToken))
        );

        if (!success) revert YearnStrategy__Inexistent_Pool(position.owedToken);

        address yvault = abi.decode(return_data, (address));
        amountIn = IYearnVault(yvault).withdraw(position.allowance, address(this), 1);
        */
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        // TBD
    }
}
