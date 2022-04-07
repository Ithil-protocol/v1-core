// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AbstractStrategy } from "./AbstractStrategy.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { VaultState } from "../libraries/VaultState.sol";

/// @title    Liquidable contract
/// @author   Ithil
/// @notice   Liquidable contract to collect liquidator data and functions

abstract contract Liquidable is AbstractStrategy {
    using TransferHelper for IERC20;
    using SafeERC20 for IERC20;

    address public immutable liquidator;

    mapping(address => uint256) public riskFactors;

    error Position_Not_Liquidable(int256);
    error Insufficient_Margin_Call(uint256);
    error Insufficient_Price(uint256);

    constructor(address _liquidator, address _vault) AbstractStrategy(_vault) {
        liquidator = _liquidator;
    }

    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert Only_Liquidator(msg.sender, liquidator);
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
            (expectedTokens, ) = quote(position.heldToken, position.owedToken, position.principal + dueFees);
            profitAndLoss = int256(position.allowance) - int256(expectedTokens);
        }

        score = int256(position.collateral * pairRiskFactor) - profitAndLoss * int24(VaultMath.RESOLUTION);
    }

    function forcefullyClose(uint256 _id) external override onlyLiquidator {
        Position memory position = positions[_id];

        (int256 score, ) = computeLiquidationScore(position);
        if (score > 0) {
            delete positions[_id];
            uint256 expectedCost = 0;
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;
            if (collateralInHeldTokens)
                (expectedCost, ) = quote(position.owedToken, position.heldToken, position.principal + position.fees);
            else expectedCost = position.allowance;
            _closePosition(position, expectedCost);
            emit PositionWasLiquidated(_id);
        }
    }

    function forcefullyDelete(
        address purchaser,
        uint256 positionId,
        uint256 price
    ) external override onlyLiquidator {
        Position memory position = positions[positionId];
        (int256 score, ) = computeLiquidationScore(position);
        if (score > 0) {
            //todo: properly repay the vault
            delete positions[positionId];
            (, uint256 received) = IERC20(position.owedToken).transferTokens(purchaser, address(vault), price);
            //todo: calculate fees!
            if (received < position.principal + position.fees) revert Insufficient_Price(price);
            else IERC20(position.heldToken).safeTransfer(purchaser, position.allowance);

            emit PositionWasLiquidated(positionId);
        }
    }

    function modifyCollateralAndOwner(
        uint256 _id,
        uint256 newCollateral,
        address newOwner
    ) external override onlyLiquidator {
        Position storage position = positions[_id];
        (int256 score, ) = computeLiquidationScore(position);
        if (score > 0) {
            positions[_id].owner = newOwner;
            (, uint256 received) = IERC20(position.collateralToken).topUpCollateral(
                positions[_id],
                newOwner,
                address(this),
                newCollateral
            );
            (int256 newScore, ) = computeLiquidationScore(position);
            if (newScore > 0) revert Insufficient_Margin_Call(received);
        }
    }
}
