// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
// import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { IAuraBooster } from "../interfaces/external/IAuraBooster.sol";
import { BalancerHelper } from "../libraries/BalancerHelper.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import "hardhat/console.sol";

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
            maxOrMin // minOut
        );
        balancerVault.exitPool(pool.id, address(this), payable(address(vault)), request);
        amountIn = owedToken.balanceOf(address(vault)) - owedBalance;
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        // weight of DAI in this pool and swap percentage fees
        /// @dev needs to be fetched!
        uint256 quoted;
        bool isJoining = pools[dst].poolAddress != address(0);
        BalancerHelper.PoolData memory pool = isJoining ? pools[dst] : pools[src];
        IERC20 bpToken = IERC20(pool.poolAddress);
        (address[] memory tokens, uint256[] memory totalBalances, ) = balancerVault.getPoolTokens(pool.id);
        uint8 tokenIndex = BalancerHelper.getTokenIndex(tokens, isJoining ? src : dst);
        quoted = isJoining
            ? BalancerHelper.computeBptOut(amount, bpToken.totalSupply(), totalBalances[tokenIndex], 4e17, 5e14)
            : BalancerHelper.computeAmountOut(amount, bpToken.totalSupply(), totalBalances[tokenIndex], 4e17, 5e14);

        return (quoted, quoted);
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function addPool(address poolAddress, bytes32 poolID) external onlyOwner {
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
        delete pools[poolAddress];
        
        emit BalancerPoolWasRemoved(poolAddress);
    }
}
