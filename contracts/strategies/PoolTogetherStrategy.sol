// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPrizePool } from "@pooltogether/v4-core/contracts/interfaces/IPrizePool.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/*
contract PoolTogetherStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error PoolTogetherStrategy__Restricted_Access();
    error PoolTogetherStrategy__Not_Enough_Liquidity();

    IPrizePool internal immutable pool;

    constructor(address _pool, address _vault) BaseStrategy(_vault) {
        pool = IPrizePool(_pool);
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal override returns (uint256 amountIn) {
        IERC20 tkn = IERC20(order.spentToken);
        amountIn = borrowed + collateralReceived;

        if(tkn.balanceOf(address(this)) < amountIn)
            revert YearnStrategy__Not_Enough_Liquidity();

        if (tkn.allowance(address(this), vaultAddress) == 0) {
            tkn.safeApprove(vaultAddress, type(uint256).max);
        }

        pool.depositTo(address(this), amountIn);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        amountOut = pool.withdrawFrom(address(this), position.allowance);
    }

    function _quote(
        address src,
        address dst,
        uint256 amount
    ) internal view override returns (uint256, uint256) {
        // TBD

        //return (obtained, obtained);
    }
}
*/
