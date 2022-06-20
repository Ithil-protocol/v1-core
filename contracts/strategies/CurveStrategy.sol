// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWETH } from "../interfaces/IWETH.sol";
import { IStETH } from "../interfaces/IStETH.sol";
import { ICurve } from "../interfaces/ICurve.sol";
import { IBooster } from "../interfaces/IBooster.sol";
import { IBaseRewardPool } from "../interfaces/IBaseRewardPool.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { BaseStrategy } from "./BaseStrategy.sol";
import "hardhat/console.sol";

/// @title    CurveStrategy contract
/// @author   Ithil
/// @notice   A strategy to perform leveraged liquidity provisioning on Curve
/// @dev      Adds a token to a Curve pool and stakes the resulting LP on Yearn

contract CurveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStETH;

    error CurveStrategy__Token_Not_Supported();
    error CurveStrategy__Not_Enough_Liquidity();
    error CurveStrategy__Convex_Pool_Deactivated(uint256 pid);

    struct CurvePool {
        uint256 pid; // Convex pool ID
        address pool;
        address lpToken;
        uint8 coins; // number of tokens
        uint256 tokenIndex; // Curve token index
        address baseRewardPool; // Convex rewards pool
    }
    mapping(address => CurvePool) internal pools; // token => Curve pool
    IBooster internal immutable booster;
    IERC20 internal immutable crv;
    IERC20 internal immutable cvx;

    constructor(
        address _vault,
        address _liquidator,
        address _booster,
        address _crv,
        address _cvx
    ) BaseStrategy(_vault, _liquidator) {
        booster = IBooster(_booster);
        crv = IERC20(_crv);
        cvx = IERC20(_cvx);
    }

    function name() external pure override returns (string memory) {
        return "CurveStrategy";
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        if (pools[order.spentToken].pool == address(0)) revert CurveStrategy__Token_Not_Supported();

        CurvePool memory p = pools[order.spentToken];
        ICurve pool = ICurve(p.pool);

        uint256 minAmount = 0;
        if (p.coins == 3) {
            uint256[3] memory amounts;

            if (p.tokenIndex == 0) amounts = [order.maxSpent, uint256(0), uint256(0)];
            else if (p.tokenIndex == 1) amounts = [uint256(0), order.maxSpent, uint256(0)];
            else amounts = [uint256(0), uint256(0), order.maxSpent];

            try pool.calc_token_amount(amounts, true) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts);
            }

            amountIn = pool.add_liquidity(amounts, minAmount - minAmount / 10); /// @todo check slippage
        } else {
            uint256[2] memory amounts;

            if (p.tokenIndex == 0) amounts = [order.maxSpent, uint256(0)];
            else amounts = [uint256(0), order.maxSpent];

            try pool.calc_token_amount(amounts, true) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts);
            }

            amountIn = pool.add_liquidity(amounts, minAmount - minAmount / 10); /// @todo check slippage
        }

        booster.depositAll(p.pid, true);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        CurvePool memory p = pools[position.owedToken];
        ICurve pool = ICurve(p.pool);

        _harvest(p.baseRewardPool, position.allowance);

        /// @todo check slippage
        uint256 expectedIn = pool.calc_withdraw_one_coin(position.allowance, p.tokenIndex);

        amountIn = pool.remove_liquidity_one_coin(position.allowance, p.tokenIndex, expectedIn);

        IERC20(position.heldToken).safeTransfer(address(vault), amountIn);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        ICurve pool = ICurve(pools[src].pool);
        uint256 obtained = (amount * 10**36) / pool.get_virtual_price();
        return (obtained, obtained);
    }

    function addCurvePool(
        address token,
        uint256 pid,
        address pool,
        uint8 coins,
        uint256 tokenIndex
    ) external onlyOwner {
        IBooster.PoolInfo memory poolInfo = booster.poolInfo(pid);
        if (poolInfo.shutdown) revert CurveStrategy__Convex_Pool_Deactivated(pid);

        // allow Curve pool to take tokens from the strategy
        super._maxApprove(IERC20(token), pool);
        // allow Convex booster to take Curve LP tokens from the strategy
        super._maxApprove(IERC20(poolInfo.lptoken), address(booster));

        pools[token] = CurvePool(pid, pool, poolInfo.lptoken, coins, tokenIndex, poolInfo.crvRewards);
    }

    function _harvest(address rewardPool, uint256 amount) internal {
        IBaseRewardPool baseRewardPool = IBaseRewardPool(rewardPool);
        baseRewardPool.withdrawAndUnwrap(amount, false); /// @todo may be true
        baseRewardPool.getReward(address(this), true); /// @todo getting rewards for the whole deposit?

        uint256 _crv = crv.balanceOf(address(this));
        uint256 _cvx = cvx.balanceOf(address(this));
        console.log("_crv", _crv);
        console.log("_cvx", _cvx);

        /// @todo swap tokens
    }
}
