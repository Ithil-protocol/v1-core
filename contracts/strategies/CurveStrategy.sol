// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWETH } from "../interfaces/IWETH.sol";
import { IStETH } from "../interfaces/IStETH.sol";
import { ICurve, ICurveA, ICurveY } from "../interfaces/ICurve.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";
import { IYearnRegistry } from "../interfaces/IYearnRegistry.sol";
import { IYearnPartnerTracker } from "../interfaces/IYearnPartnerTracker.sol";
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

    struct Pool {
        address pool;
        bool atype;
        uint8 n; // number of tokens
    }
    mapping(address => Pool) internal pools; // token => Curve pool
    IYearnRegistry internal immutable registry;
    IYearnPartnerTracker internal immutable yearnPartnerTracker;
    address internal immutable partnerId;

    constructor(
        address _vault,
        address _liquidator,
        address _registry,
        address _partnerId,
        address _yearnPartnerTracker
    ) BaseStrategy(_vault, _liquidator) {
        partnerId = _partnerId;
        registry = IYearnRegistry(_registry);
        yearnPartnerTracker = IYearnPartnerTracker(_yearnPartnerTracker);
    }

    function name() external pure override returns (string memory) {
        return "CurveStrategy";
    }

    function _openPosition(Order memory order) internal override returns (uint256 amountIn) {
        if (pools[order.spentToken].pool == address(0)) revert CurveStrategy__Token_Not_Supported();

        ICurve pool = ICurve(pools[order.spentToken].pool);

        address lpToken;
        try pool.lp_token() returns (address val) {
            lpToken = val;
        } catch {
            lpToken = pool.token();
        }

        uint256 lpTokenAmount = pools[order.spentToken].atype
            ? _addLiquidityAdapterAPool(order.spentToken, order.maxSpent)
            : _addLiquidityAdapterYPool(order.spentToken, order.maxSpent);

        IYearnVault yvault = IYearnVault(registry.latestVault(lpToken));
        amountIn = yearnPartnerTracker.deposit(address(yvault), partnerId, lpTokenAmount);
    }

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        override
        returns (uint256 amountIn, uint256 amountOut)
    {
        ICurve pool = ICurve(pools[position.heldToken].pool);

        IYearnVault yvault = IYearnVault(registry.latestVault(pool.lp_token()));
        (uint256 expectedIn, ) = quote(address(yvault), position.heldToken, expectedCost);

        uint256 amount = yvault.withdraw(position.allowance, address(this), 100);

        amountIn = _removeLiquidityAdapter(position.heldToken, amount, expectedIn);

        IERC20(position.heldToken).safeTransfer(address(vault), amountIn);
    }

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view override returns (uint256, uint256) {
        // TBD
    }

    function _getTokenIndex(address token, ICurve pool) internal view returns (uint8 i) {
        while (i < 3) {
            if (pool.coins(i) == token) break;
            ++i;
        }
    }

    function _addLiquidityAdapterAPool(address token, uint256 amount) internal returns (uint256) {
        uint256 lpTokenAmount = 0;

        ICurveA pool = ICurveA(pools[token].pool);
        uint8 i = _getTokenIndex(token, pool);
        if (pools[token].n == 3) {
            uint256[3] memory amounts;

            if (i == 0) amounts = [amount, uint256(0), uint256(0)];
            else if (i == 1) amounts = [uint256(0), amount, uint256(0)];
            else amounts = [uint256(0), uint256(0), amount];

            uint256 minAmount = 0;
            try pool.calc_token_amount(amounts) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts, true);
            }

            lpTokenAmount = pool.add_liquidity(amounts, minAmount, true);
        } else {
            uint256[2] memory amounts;

            if (i == 0) amounts = [amount, uint256(0)];
            else amounts = [uint256(0), amount];

            uint256 minAmount = 0;
            try pool.calc_token_amount(amounts) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts, true);
            }

            lpTokenAmount = pool.add_liquidity(amounts, minAmount, true);
        }

        return lpTokenAmount;
    }

    function _addLiquidityAdapterYPool(address token, uint256 amount) internal returns (uint256) {
        uint256 lpTokenAmount = 0;

        ICurveY pool = ICurveY(pools[token].pool);
        uint8 i = _getTokenIndex(token, pool);
        if (pools[token].n == 3) {
            uint256[3] memory amounts;

            if (i == 0) amounts = [amount, uint256(0), uint256(0)];
            else if (i == 1) amounts = [uint256(0), amount, uint256(0)];
            else amounts = [uint256(0), uint256(0), amount];

            uint256 minAmount = 0;
            try pool.calc_token_amount(amounts) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts, true);
            }

            lpTokenAmount = pool.add_liquidity(amounts, minAmount);
        } else {
            uint256[2] memory amounts;

            if (i == 0) amounts = [amount, uint256(0)];
            else amounts = [uint256(0), amount];

            uint256 minAmount = 0;
            try pool.calc_token_amount(amounts) returns (uint256 val) {
                minAmount = val;
            } catch {
                minAmount = pool.calc_token_amount(amounts, true);
            }

            console.log("amounts[0]", amounts[0]);
            console.log("amounts[0]", amounts[1]);
            console.log("minAmount", minAmount);

            lpTokenAmount = pool.add_liquidity(amounts, minAmount - minAmount / 10);
        }

        return lpTokenAmount;
    }

    function _removeLiquidityAdapter(
        address token,
        uint256 amount,
        uint256 minAmount
    ) internal returns (uint256) {
        uint256 amountIn = 0;

        if (pools[token].atype) {
            ICurveA pool = ICurveA(pools[token].pool);
            uint128 i = _getTokenIndex(token, pool);

            amountIn = pool.remove_liquidity_one_coin(amount, int128(i), minAmount, true);
        } else {
            ICurveY pool = ICurveY(pools[token].pool);
            uint128 i = _getTokenIndex(token, pool);

            amountIn = pool.remove_liquidity_one_coin(amount, int128(i), minAmount);
        }

        return amountIn;
    }

    function addCurvePool(
        address token,
        address pool,
        bool atype,
        uint8 n
    ) external onlyOwner {
        pools[token] = Pool(pool, atype, n);
    }

    function removeCurvePool(address token) external onlyOwner {
        delete pools[token];
    }
}
