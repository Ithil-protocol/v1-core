// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { IAuraBooster } from "../interfaces/external/IAuraBooster.sol";
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

        IERC20 bpToken = IERC20(pool.poolAddress);
        uint256 bptInitialBalance = bpToken.balanceOf(address(this));

        IBalancerVault.JoinPoolRequest memory request = BalancerHelper.joinPoolRequest(
            pool,
            order.spentToken,
            order.maxSpent,
            order.minObtained
        );
        balancerVault.joinPool(pool.id, address(this), address(this), request);

        amountIn = bpToken.balanceOf(address(this)) - bptInitialBalance;
    }

    function _closePosition(Position memory position, uint256 maxOrMin)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        BalancerHelper.PoolData memory pool = pools[position.heldToken];
        IERC20 owedToken = IERC20(position.owedToken);
        uint256 owedBalance = owedToken.balanceOf(address(vault));
        IBalancerVault.ExitPoolRequest memory request = BalancerHelper.exitPoolRequest(
            pool,
            position.owedToken,
            position.allowance, // bptIn
            42000000 // minOut
        );
        balancerVault.exitPool(pool.id, address(this), payable(address(vault)), request);
        amountIn = owedToken.balanceOf(address(vault)) - owedBalance;
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        if (pools[src].poolAddress != address(0)) {
            // exiting
        } else if (pools[dst].poolAddress != address(0)) {
            // joining
        }

        // pool not supported
        return (0, 0);
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
            // @todo check allowance first?
            IERC20(poolTokens[i]).approve(address(balancerVault), type(uint256).max);
            //IERC20(poolTokens[i]).approve(address(aura), type(uint256).max);
        }

        emit BalancerPoolWasAdded(poolAddress);
    }

    function removePool(address poolAddress) external onlyOwner {
        BalancerHelper.PoolData memory pool = pools[poolAddress];
        delete pools[poolAddress];

        for (uint8 i = 0; i < pool.tokens.length; i++) {
            IERC20(pool.tokens[i]).approve(pool.poolAddress, 0);
            //IERC20(pool.tokens[i]).approve(pool.auraPoolAddress, 0);
        }

        emit BalancerPoolWasRemoved(poolAddress);
    }

    /*
    function _getMinAmountOut(address pool, uint256 amountIn, uint256 slippage)
        internal
        view
        returns (uint256 minAmountOut)
    {
        uint256 price;
        if (tokenIn == _token && tokenOut == _pool) {
            price = FixedPoint.ONE.divUp(getRate());
        } else if (tokenIn == _pool && tokenOut == _token) {
            price = getRate();
        }

        minAmountOut = amountIn.mulUp(price).mulUp(FixedPoint.ONE - slippage);
    }
    */

    /*
    function pooledBalance(address _token, uint256 amount) public view returns (uint256) {
        BalancerHelper.PoolData memory data = pools[_token];

        uint256 totalUnderlyingPooled;
        (, uint256[] memory totalBalances, uint256 lastChangeBlock) = balancerVault
            .getPoolTokens(data.id);

        IBalancerPool pool = IBalancerPool(data.poolAddress);
        uint256 bptBalance = pool.balanceOf(address(this));
        uint256 _nPoolTokens = data.tokens.length; // save SLOADs
        uint8 underlyingIndex = 0;
        address underlyingAsset = address(data.tokens[underlyingIndex]); // save SLOADs
        for (uint8 i = 0; i < _nPoolTokens; i++) {
            uint256 tokenPooled = (totalBalances[i] * bptBalance) / pool.totalSupply();
            if (tokenPooled > 0) {
                IERC20 token = IERC20(data.tokens[i]);
                if (address(token) != underlyingAsset) {
                    IBalancerPool.SwapRequest memory request = IBalancerPool.SwapRequest(
                        IBalancerPool.SwapKind.GIVEN_IN,
                        token,
                        IERC20(_token),
                        amount,
                        data.id,
                        lastChangeBlock,
                        address(this),
                        address(this),
                        abi.encode(0)
                    );
                    tokenPooled = pool.onSwap(request, totalBalances, i, underlyingIndex);
                }
                totalUnderlyingPooled += tokenPooled;
            }
        }
        return totalUnderlyingPooled;
    }
    */
}
