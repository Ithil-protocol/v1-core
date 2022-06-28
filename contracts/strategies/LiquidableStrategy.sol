// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AbstractStrategy } from "./AbstractStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { PositionHelper } from "../libraries/PositionHelper.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { VaultState } from "../libraries/VaultState.sol";

/// @title    LiquidableStrategy contract
/// @author   Ithil
/// @notice   Liquidable contract to collect liquidator data and functions
abstract contract LiquidableStrategy is AbstractStrategy {
    using TransferHelper for IERC20;
    using PositionHelper for Position;
    using SafeERC20 for IERC20;

    address public immutable liquidator;

    mapping(address => uint256) public riskFactors;

    error Position_Not_Liquidable(int256 liquidationScore);
    error Insufficient_Margin_Call(uint256 received);
    error Insufficient_Price(uint256 price);

    constructor(
        address _liquidator,
        address _vault,
        string memory _name,
        string memory _symbol
    ) AbstractStrategy(_vault, _name, _symbol) {
        liquidator = _liquidator;
    }

    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert Strategy__Only_Liquidator(msg.sender, liquidator);
        _;
    }

    function computePairRiskFactor(address token0, address token1) public view override returns (uint256) {
        return (riskFactors[token0] + riskFactors[token1]) / 2;
    }

    function computeLiquidationScore(Position memory position) public view returns (int256 score, uint256 dueFees) {
        bool collateralInOwedToken = position.collateralToken != position.heldToken;
        uint256 pairRiskFactor = computePairRiskFactor(position.heldToken, position.owedToken);
        uint256 expectedTokens;
        int256 profitAndLoss;

        dueFees =
            position.fees +
            (position.interestRate * (block.timestamp - position.createdAt) * position.principal) /
            (uint32(VaultMath.TIME_FEE_PERIOD) * VaultMath.RESOLUTION);

        if (collateralInOwedToken) {
            (expectedTokens, ) = quote(position.heldToken, position.owedToken, position.allowance);
            profitAndLoss = int256(expectedTokens) - int256(position.principal + dueFees);
        } else {
            (expectedTokens, ) = quote(position.owedToken, position.heldToken, position.principal + dueFees);
            profitAndLoss = int256(position.allowance) - int256(expectedTokens);
        }

        score = int256(position.collateral * pairRiskFactor) - profitAndLoss * int24(VaultMath.RESOLUTION);
    }

    function forcefullyClose(
        uint256 _id,
        address _liquidator,
        uint256 reward
    ) external override onlyLiquidator {
        Position memory position = positions[_id];

        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            delete positions[_id];
            _burn(_id);
            uint256 expectedCost = 0;
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;
            if (collateralInHeldTokens)
                (expectedCost, ) = quote(position.owedToken, position.heldToken, position.principal + dueFees);
            else expectedCost = position.allowance;
            (uint256 amountIn, ) = _closePosition(position, expectedCost);
            vault.repay(
                position.owedToken,
                amountIn,
                position.principal,
                dueFees,
                riskFactors[position.heldToken],
                _liquidator
            );

            emit PositionWasLiquidated(_id);
        } else revert Strategy__Nonpositive_Score(score);
    }

    function transferAllowance(
        uint256 positionId,
        uint256 price,
        address purchaser,
        uint256 reward
    ) external override onlyLiquidator {
        Position memory position = positions[positionId];
        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            delete positions[positionId];
            (, uint256 received) = IERC20(position.owedToken).transferTokens(purchaser, address(vault), price);
            if (received < position.principal + dueFees)
                revert Strategy__Insufficient_Amount_Out(received, position.principal + dueFees);
            else IERC20(position.heldToken).safeTransfer(purchaser, position.allowance);

            _burn(positionId);

            emit PositionWasLiquidated(positionId);
        } else revert Strategy__Nonpositive_Score(score);
    }

    function modifyCollateralAndOwner(
        uint256 _id,
        uint256 newCollateral,
        address newOwner,
        uint256 reward
    ) external override onlyLiquidator {
        Position storage position = positions[_id];
        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            _transfer(ownerOf(_id), newOwner, _id);
            position.fees += dueFees;
            position.createdAt = block.timestamp;
            position.topUpCollateral(
                newOwner,
                position.collateralToken != position.heldToken ? address(vault) : address(this),
                newCollateral,
                position.collateralToken != position.heldToken
            );
            (int256 newScore, ) = computeLiquidationScore(position);
            if (newScore > 0) revert Strategy__Insufficient_Margin_Provided(newScore);
        } else revert Strategy__Nonpositive_Score(score);
    }
}
