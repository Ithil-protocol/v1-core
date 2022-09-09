// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { BalancerHelper } from "../libraries/BalancerHelper.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import "hardhat/console.sol";


interface IERC20s is IERC20 {
    function name() external view returns (string memory);
    function decimals() external view returns (uint256);
}

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

        IERC20s lpToken = IERC20s(pool.poolAddress);
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
            position.owedToken,
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
        } else {
            // joining
        }
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
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

    /*
    function removePool(address poolAddress) external onlyOwner {
        delete pools[poolAddress];

        emit BalancerPoolWasRemoved(poolAddress);
    }
    */

    /**
     * @dev Tells the exchange rate for a BPT expressed in the strategy token. Since here we are working with stable
     *      pools, it can be simply computed using the pool rate.
     */
     /*
    function getTokenPerBptPrice() public view override returns (uint256) {
        uint256 rate = IBalancerPool(address(_pool)).getRate();
        return rate / _tokenScale;
    }
    */

    /**
     * @dev Tells the expected min amount for a swap using the price oracle or the pool itself for joins and exits
     * @param tokenIn Token to be sent
     * @param tokenOut Token to received
     * @param amountIn Amount of tokenIn being swapped
     * @param slippage Slippage to be used to compute the min amount out
     */
    /*
    function _getMinAmountOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 slippage)
        internal
        view
        returns (uint256 minAmountOut)
    {
        uint256 price;
        if (tokenIn == _token && tokenOut == _pool) {
            price = FixedPoint.ONE.divUp(getTokenPerBptPrice());
        } else if (tokenIn == _pool && tokenOut == _token) {
            price = getTokenPerBptPrice();
        }

        minAmountOut = amountIn.mulUp(price).mulUp(FixedPoint.ONE - slippage);
    }
    */
}
