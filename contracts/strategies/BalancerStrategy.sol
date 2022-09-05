// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { BalancerHelper } from "../libraries/BalancerHelper.sol";
import { BaseStrategy } from "./BaseStrategy.sol";

/// @title    BalancerStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged lping on any Balancer pool
contract BalancerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    event BalancerPoolWasAdded(address pool);
    event BalancerPoolWasRemoved(address pool);

    error BalancerStrategy__Inexistent_Pool(address pool);

    mapping(address => BalancerHelper.PoolData) public pools;
    IBalancerVault internal immutable balancerVault;

    constructor(
        address _vault,
        address _liquidator,
        address _balancerVault
    ) BaseStrategy(_vault, _liquidator, "BalancerStrategy", "ITHIL-BS-POS") {
        balancerVault = IBalancerVault(_balancerVault);
    }

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        BalancerHelper.PoolData memory pool = pools[order.obtainedToken];
        if (pool.poolAddress == address(0)) revert BalancerStrategy__Inexistent_Pool(order.spentToken);

        IERC20 lpToken = IERC20(pool.poolAddress);
        uint256 initialBalance = lpToken.balanceOf(address(this));

        IBalancerVault.JoinPoolRequest memory request = BalancerHelper.joinPoolRequest(
            pool,
            order.spentToken,
            order.maxSpent,
            order.minObtained
        );
        balancerVault.joinPool(pool.id, address(this), address(this), request);

        amountIn = lpToken.balanceOf(address(this)) - initialBalance;
    }

    function _closePosition(Position memory position, uint256 maxOrMin)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        BalancerHelper.PoolData memory pool = pools[position.heldToken];

        IBalancerVault.ExitPoolRequest memory request = BalancerHelper.exitPoolRequest(
            pool,
            position.heldToken,
            position.allowance,
            maxOrMin
        );
        balancerVault.exitPool(pool.id, address(this), payable(address(this)), request);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        if (pools[src].poolAddress != address(0)) {
            // exiting
            BalancerHelper.PoolData memory pool = pools[src];
            IBalancerVault.ExitPoolRequest memory request = BalancerHelper.exitPoolRequest(pool, dst, amount, 0);

            //IBalancerPool(pool.poolAddress).queryExit(pool.id, address(this), address(this), request);
        } else {
            // joining
            BalancerHelper.PoolData memory pool = pools[dst];
            IBalancerVault.JoinPoolRequest memory request = BalancerHelper.joinPoolRequest(pool, src, amount, 0);

            //IBalancerPool(pool.poolAddress).queryJoin(pool.id, address(this), address(this), request);
        }
    }

    function addPool(address poolAddress) external onlyOwner {
        IBalancerPool balancerPool = IBalancerPool(poolAddress);
        bytes32 poolID = balancerPool.getPoolId();
        (address[] memory poolTokens, , ) = balancerVault.getPoolTokens(poolID);
        pools[poolAddress] = BalancerHelper.PoolData(poolID, poolAddress, poolTokens, uint8(poolTokens.length));

        for (uint8 i = 0; i < poolTokens.length; i++) {
            super._maxApprove(IERC20(poolTokens[i]), address(balancerVault));
        }

        emit BalancerPoolWasAdded(poolAddress);
    }

    function removePool(address poolAddress) external onlyOwner {
        delete pools[poolAddress];

        emit BalancerPoolWasRemoved(poolAddress);
    }
}
