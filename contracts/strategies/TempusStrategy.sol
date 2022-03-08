// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITempusController } from "../interfaces/ITempusController.sol";
import { ITempusPool } from "../interfaces/ITempusPool.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

contract TempusStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error TempusStrategy__Not_Enough_Liquidity();
    error TempusStrategy__Inexistent_Pool(address);

    ITempusController internal immutable controller;
    mapping(address => address) public pools;

    constructor(
        address _controller,
        address _vault,
        address _liquidator
    ) BaseStrategy(_vault, _liquidator) {
        controller = ITempusController(_controller);
    }

    function name() external pure override returns (string memory) {
        return "TempusStrategy";
    }

    function _getPool(address token) internal view returns (address) {
        address pool = pools[token];
        if (pool == address(0)) revert TempusStrategy__Inexistent_Pool(token);

        return pool;
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        IERC20 tkn = IERC20(order.spentToken);
        uint256 amount = borrowed + collateralReceived;

        if (tkn.balanceOf(address(this)) < amount) revert TempusStrategy__Not_Enough_Liquidity();

        address pool = _getPool(order.spentToken);

        if (tkn.allowance(address(this), pool) == 0) {
            tkn.safeApprove(pool, type(uint256).max);
        }

        amountIn = controller.depositBacking(ITempusPool(pool), amount, address(this));
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        // TBD
        //address pool = _getPool(position.owedToken);
        // controller.redeemToBacking(pool, ); TBD
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        /// TBD
    }
}
