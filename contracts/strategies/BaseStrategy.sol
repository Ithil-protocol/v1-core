// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is IStrategy, Ownable {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    IVault public immutable vault;
    uint256 public id;
    mapping(address => uint256) public riskFactors;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256) public totalAllowances;

    constructor(address _vault) {
        vault = IVault(_vault);
        id = 0;
    }

    modifier validOrder(Order memory order) {
        if (order.spentToken == order.obtainedToken) revert Source_Eq_Dest(order.spentToken);
        if (order.collateral == 0)
            // @todo should add minimum margin check here
            revert Insufficient_Collateral(order.collateral);
        _;
    }

    modifier validPosition(uint256 positionId) {
        bool nonzero = positions[positionId].owner != address(0);
        if (!nonzero) revert Invalid_Position(positionId, address(this));
        _;
    }

    function setRiskFactor(address token, uint256 riskFactor) external onlyOwner {
        riskFactors[token] = riskFactor;
    }

    function computePairRiskFactor(address token0, address token1) public view returns (uint256) {
        return (riskFactors[token0] + riskFactors[token1]) / 2;
    }

    function openPosition(Order memory order) external validOrder(order) returns (uint256) {
        uint256 collateralPlaced = 0;
        uint256 riskFactor = computePairRiskFactor(order.spentToken, order.obtainedToken);
        IERC20 collateralToken;
        if (order.collateralIsSpentToken) collateralToken = IERC20(order.spentToken);
        else collateralToken = IERC20(order.obtainedToken);

        (, uint256 collateralReceived) = collateralToken.transferTokens(msg.sender, address(this), order.collateral);

        if (!order.collateralIsSpentToken)
            (collateralPlaced, ) = _quote(order.spentToken, order.obtainedToken, collateralReceived);

        if (order.collateralIsSpentToken) {
            order.maxSpent -= collateralReceived;
            collateralPlaced = collateralReceived;
        }

        (uint256 interestRate, uint256 fees, uint256 debt, uint256 borrowed) = vault.borrow(
            order.spentToken,
            order.maxSpent,
            collateralPlaced,
            riskFactor,
            msg.sender
        );

        uint256 amountIn = _openPosition(order, borrowed, collateralReceived);

        positions[++id] = Position({
            owner: msg.sender,
            owedToken: order.spentToken,
            heldToken: order.obtainedToken,
            collateralToken: address(collateralToken),
            collateral: collateralReceived,
            principal: debt,
            allowance: amountIn,
            interestRate: interestRate,
            fees: fees,
            createdAt: block.timestamp
        });

        emit PositionWasOpened(
            id,
            msg.sender,
            order.spentToken,
            order.obtainedToken,
            address(collateralToken),
            collateralReceived,
            debt,
            amountIn,
            interestRate,
            block.timestamp
        );

        return id;
    }

    function closePosition(uint256 positionId) external validPosition(positionId) {
        if (positions[positionId].owner != msg.sender)
            revert Restricted_Access(positions[positionId].owner, msg.sender);

        Position memory position = positions[positionId];

        delete positions[positionId];

        uint256 timeFees = VaultMath.computeTimeFees(
            position.principal,
            position.interestRate,
            block.timestamp - position.createdAt
        );

        position.fees += timeFees;

        if (totalAllowances[position.heldToken] > 0) {
            uint256 nominalAllowance = position.allowance;
            totalAllowances[position.heldToken] -= nominalAllowance;
            position.allowance *= IERC20(position.heldToken).balanceOf(address(this));
            position.allowance /= (totalAllowances[position.heldToken] + nominalAllowance);
        }

        uint256 expectedCost = 0;
        bool collateralInHeldTokens = position.collateralToken != position.owedToken;

        if (collateralInHeldTokens)
            (expectedCost, ) = _quote(position.owedToken, position.heldToken, position.principal + position.fees);

        (uint256 amountIn, uint256 amountOut) = _closePosition(position, expectedCost);

        if (collateralInHeldTokens && amountOut <= position.allowance)
            IERC20(position.heldToken).safeTransfer(position.owner, position.allowance - amountOut);

        vault.repay(position.owedToken, amountIn, position.principal, position.fees, position.owner);

        emit PositionWasClosed(positionId);
    }

    function editPosition(uint256 positionId, uint256 newCollateral) external validPosition(positionId) {
        Position storage position = positions[positionId];
        if (position.owner != msg.sender) revert Restricted_Access(position.owner, msg.sender);

        IERC20 tokenToTransfer = IERC20(position.collateralToken);

        position.collateral += newCollateral;
        if (position.collateralToken == position.owedToken)
            tokenToTransfer.safeTransferFrom(msg.sender, address(vault), newCollateral);
        else tokenToTransfer.safeTransferFrom(msg.sender, address(this), newCollateral);
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
            (expectedTokens, ) = _quote(position.heldToken, position.owedToken, position.allowance);
            profitAndLoss = int256(expectedTokens) - int256(position.principal + dueFees);
        } else {
            (expectedTokens, ) = _quote(position.heldToken, position.owedToken, position.principal + dueFees);
            profitAndLoss = int256(position.allowance) - int256(expectedTokens);
        }

        score = int256(position.collateral * pairRiskFactor) - profitAndLoss * int24(VaultMath.RESOLUTION);
    }

    function liquidate(uint256[] memory positionIds) external {
        //todo: add checks on liquidator
        Position memory modelPosition = positions[positionIds[0]];
        modelPosition.allowance = 0;
        modelPosition.principal = 0;
        modelPosition.fees = 0;
        modelPosition.interestRate = 0;
        modelPosition.owner = msg.sender;
        for (uint256 i = 0; i < positionIds.length; i++) {
            Position memory position = positions[positionIds[i]];

            if (position.heldToken != modelPosition.heldToken || position.owedToken != modelPosition.owedToken)
                continue;

            if (totalAllowances[position.heldToken] > 0) {
                uint256 nominalAllowance = position.allowance;
                totalAllowances[position.heldToken] -= nominalAllowance;
                position.allowance *= IERC20(position.heldToken).balanceOf(address(this));
                position.allowance /= (totalAllowances[position.heldToken] + nominalAllowance);
            }

            (int256 score, uint256 dueFees) = computeLiquidationScore(position);
            if (score > 0) {
                delete positions[positionIds[i]];
                modelPosition.allowance += position.allowance;
                modelPosition.principal += position.principal;
                modelPosition.fees += dueFees;
                emit PositionWasLiquidated(positionIds[i]);
            }
        }

        uint256 expectedCost = 0;
        bool collateralInHeldTokens = modelPosition.collateralToken != modelPosition.owedToken;

        if (collateralInHeldTokens)
            (expectedCost, ) = _quote(
                modelPosition.owedToken,
                modelPosition.heldToken,
                modelPosition.principal + modelPosition.fees
            );
        if (modelPosition.allowance > 0) _closePosition(modelPosition, expectedCost);
    }

    function _openPosition(
        Order memory order,
        uint256 borrowed,
        uint256 collateralReceived
    ) internal virtual returns (uint256);

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        virtual
        returns (uint256 amountIn, uint256 amountOut);

    function _quote(
        address src,
        address dst,
        uint256 amount
    ) internal view virtual returns (uint256, uint256);
}
