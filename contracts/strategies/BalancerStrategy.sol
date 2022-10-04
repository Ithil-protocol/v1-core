// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
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
        uint256 quoted;
        bool isJoining = pools[dst].poolAddress != address(0);
        BalancerHelper.PoolData memory pool = isJoining ? pools[dst] : pools[src];
        IERC20 bpToken = IERC20(pool.poolAddress);
        (address[] memory tokens, uint256[] memory totalBalances, ) = balancerVault.getPoolTokens(pool.id);
        uint8 tokenIndex = BalancerHelper.getTokenIndex(tokens, isJoining ? src : dst);
        quoted = isJoining
            ? BalancerHelper.computeBptOut(
                amount,
                bpToken.totalSupply(),
                totalBalances[tokenIndex],
                pool.weights[tokenIndex],
                pool.swapFee
            )
            : BalancerHelper.computeAmountOut(
                amount,
                bpToken.totalSupply(),
                totalBalances[tokenIndex],
                pool.weights[tokenIndex],
                pool.swapFee
            );

        return (quoted, quoted);
    }

    function exposure(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _sellRewards(address token, uint256 minOut) internal {
        uint256 amount = bal.balanceOf(address(this));

        IBalancerVault.SingleSwap memory swap = new IBalancerVault.SingleSwap({
            poolId: "",
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: token,
            assetOut: address(bal),
            amount: amount,
            userData: ""
        });

        balancerVault.swap(
            swap,
            IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
            amount,
            block.timestamp
        );

        uint256 obtained = bal.balanceOf(address(this)) - amount;

        if(obtained < minOut) revert Strategy__Insufficient_Amount_Obtained();

        /*
        uint256 balance = balBalance();

        uint256 length = pool.tokens.length;
        IBalancerVault.BatchSwapStep[] memory steps = new IBalancerVault.BatchSwapStep[](length);
        int256[] memory limits = new int256[](length + 1);
        limits[0] = int256(balance);

        for (uint256 j = 0; j < length; j++) {
            steps[j] = IBalancerVault.BatchSwapStep(balSwaps.poolIds[j], j, j + 1, j == 0 ? balance : 0, abi.encode(0));
        }

        uint256 floatBefore = float();

        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_IN,
            steps,
            balSwaps.assets,
            IBalancerVault.FundManagement(address(this), false, payable(address(this)), false),
            limits,
            block.timestamp + 1000
        );

        uint256 delta = float() - floatBefore;
        require(delta >= minOut, "sellBal::SLIPPAGE");
        */
    }

    function addPool(
        address poolAddress,
        bytes32 poolID,
        bool weighted
    ) external onlyOwner {
        (address[] memory poolTokens, , ) = balancerVault.getPoolTokens(poolID);
        uint256 length = poolTokens.length;
        IBalancerPool bpool = IBalancerPool(poolAddress);
        uint256 fee = bpool.getSwapFeePercentage();
        uint256[] memory weights = new uint256[](length);

        if (weighted) weights = bpool.getNormalizedWeights();

        for (uint8 i = 0; i < length; i++) {
            IERC20 token = IERC20(poolTokens[i]);
            if (token.allowance(address(this), address(balancerVault)) == 0)
                token.safeApprove(address(balancerVault), type(uint256).max);
            //IERC20(poolTokens[i]).approve(address(aura), type(uint256).max);
            if (!weighted) weights[i] = 1e18/length;
        }

        pools[poolAddress] = BalancerHelper.PoolData(
            poolID,
            poolAddress,
            poolTokens,
            weights,
            uint8(length),
            fee
        );

        emit BalancerPoolWasAdded(poolAddress);
    }

    function removePool(address poolAddress) external onlyOwner {
        BalancerHelper.PoolData memory pool = pools[poolAddress];
        delete pools[poolAddress];

        for (uint8 i = 0; i < pool.tokens.length; i++) {
            // @todo check allowance first?
            console.log(pool.tokens[i]);

            IERC20(pool.tokens[i]).approve(address(balancerVault), 0);
            //IERC20(poolTokens[i]).approve(address(aura), type(uint256).max);
        }
        
        emit BalancerPoolWasRemoved(poolAddress);
    }
}
