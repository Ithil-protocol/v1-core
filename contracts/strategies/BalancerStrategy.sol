// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBalancerVault } from "../interfaces/external/IBalancerVault.sol";
import { IBalancerPool } from "../interfaces/external/IBalancerPool.sol";
import { IAuraBooster } from "../interfaces/external/IAuraBooster.sol";
import { IAuraRewardPool4626 } from "../interfaces/external/IAuraRewardPool4626.sol";
import { BalancerHelper } from "../libraries/BalancerHelper.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import "hardhat/console.sol";

/// @title    BalancerStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged lping on any Balancer pool
contract BalancerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    struct PoolData {
        bytes32 balancerPoolID;
        uint256 auraPoolID;
        address[] tokens;
        uint256[] weights;
        uint8 length;
        uint256 swapFee;
        IAuraRewardPool4626 auraRewardPool;
    }

    event BalancerPoolWasAdded(address indexed pool);
    event BalancerPoolWasRemoved(address indexed pool);
    event NewHarvest(address indexed pool);
    error BalancerStrategy__Inexistent_Pool(address pool);

    mapping(address => PoolData) public pools;
    IBalancerVault internal immutable balancerVault;
    IAuraBooster internal immutable auraBooster;
    IERC20 internal immutable bal; // BAL token
    IERC20 internal immutable aura; // BAL token
    uint256 public rewardRate;

    constructor(
        address _vault,
        address _liquidator,
        address _balancerVault,
        address _auraBooster
    ) BaseStrategy(_vault, _liquidator, "BalancerStrategy", "ITHIL-BS-POS") {
        balancerVault = IBalancerVault(_balancerVault);
        auraBooster = IAuraBooster(_auraBooster);
        bal = IERC20(auraBooster.crv());
        aura = IERC20(auraBooster.minter());
    }

    function _openPosition(Order calldata order) internal override returns (uint256 amountIn) {
        PoolData memory pool = pools[order.obtainedToken];
        if (pool.length == 0) revert BalancerStrategy__Inexistent_Pool(order.spentToken);

        IERC20 bpToken = IERC20(order.obtainedToken);
        uint256 bptInitialBalance = bpToken.balanceOf(address(this));

        IBalancerVault.JoinPoolRequest memory request = BalancerHelper.joinPoolRequest(
            pool.tokens,
            order.spentToken,
            order.maxSpent,
            order.minObtained
        );
        balancerVault.joinPool(pool.balancerPoolID, address(this), address(this), request);

        amountIn = bpToken.balanceOf(address(this)) - bptInitialBalance;

        pool.auraRewardPool.deposit(amountIn, address(this));
    }

    function _closePosition(Position memory position, uint256 maxOrMin)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        PoolData memory pool = pools[position.heldToken];
        IERC20 owedToken = IERC20(position.owedToken);

        pool.auraRewardPool.withdrawAndUnwrap(position.allowance, false);

        uint256 initialBalance = owedToken.balanceOf(address(vault));
        IBalancerVault.ExitPoolRequest memory request = BalancerHelper.exitPoolRequest(
            pool.tokens,
            position.owedToken,
            position.allowance, // bptIn
            maxOrMin // minOut
        );
        balancerVault.exitPool(pool.balancerPoolID, address(this), payable(address(vault)), request);
        amountIn = owedToken.balanceOf(address(vault)) - initialBalance;
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        uint256 quoted;
        bool isJoining = pools[dst].length != 0;
        PoolData memory pool = isJoining ? pools[dst] : pools[src];
        IERC20 bpToken = isJoining ? IERC20(dst) : IERC20(src);
        (address[] memory tokens, uint256[] memory totalBalances, ) = balancerVault.getPoolTokens(pool.balancerPoolID);
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

    function harvest(address poolAddress) external returns (uint256, uint256) {
        PoolData memory pool = pools[poolAddress];
        if (pool.length == 0) revert BalancerStrategy__Inexistent_Pool(poolAddress);

        uint256 initialBalAmount = bal.balanceOf(address(this));
        uint256 initialAuraAmount = aura.balanceOf(address(this));

        pool.auraRewardPool.getReward(address(this), true);

        uint256 balReward = (bal.balanceOf(address(this)) - initialBalAmount) * rewardRate / 1000;
        uint256 auraReward = (aura.balanceOf(address(this)) - initialAuraAmount) * rewardRate / 1000;

        bal.safeTransfer(msg.sender, balReward);
        aura.safeTransfer(msg.sender, auraReward);

        emit NewHarvest(poolAddress);

        return (balReward, auraReward);
    }

    function addPool(
        address poolAddress,
        bytes32 balancerPoolID,
        uint256 auraPoolID
    ) external onlyOwner {
        (address[] memory poolTokens, , ) = balancerVault.getPoolTokens(balancerPoolID);
        uint256 length = poolTokens.length;
        IBalancerPool bpool = IBalancerPool(poolAddress);
        uint256 fee = bpool.getSwapFeePercentage();
        uint256[] memory weights = bpool.getNormalizedWeights();

        (address lptoken, , , address rewardsContract, , bool shutdown) = auraBooster.poolInfo(auraPoolID);
        assert(!shutdown);
        assert(lptoken == poolAddress);

        for (uint8 i = 0; i < length; i++) {
            if (IERC20(poolTokens[i]).allowance(address(this), address(balancerVault)) == 0)
                IERC20(poolTokens[i]).safeApprove(address(balancerVault), type(uint256).max);
            if (IERC20(lptoken).allowance(address(this), rewardsContract) == 0)
                IERC20(lptoken).safeApprove(rewardsContract, type(uint256).max);
        }

        pools[poolAddress] = PoolData(
            balancerPoolID,
            auraPoolID,
            poolTokens,
            weights,
            uint8(length),
            fee,
            IAuraRewardPool4626(rewardsContract)
        );

        emit BalancerPoolWasAdded(poolAddress);
    }

    function removePool(address poolAddress) external onlyOwner {
        PoolData memory pool = pools[poolAddress];
        delete pools[poolAddress];

        for (uint8 i = 0; i < pool.tokens.length; i++) {
            IERC20 token = IERC20(pool.tokens[i]);
            token.approve(address(balancerVault), 0);
            token.approve(address(pool.auraRewardPool), 0);
        }

        emit BalancerPoolWasRemoved(poolAddress);
    }

    function setRewardRate(uint256 val) external onlyOwner {
        rewardRate = val;
    }
}
