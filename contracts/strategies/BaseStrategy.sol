// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { Liquidable } from "./Liquidable.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is Liquidable {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    uint256 public id;

    error Obtained_Insufficient_Amount(uint256);
    error Opened_Liquidable_Position(uint256);
    error Loan_Not_Repaid(uint256, uint256);
    error Expired();

    constructor(address _vault, address _liquidator) Liquidable(_liquidator, _vault) {
        id = 0;
    }

    modifier validOrder(Order memory order) {
        if (block.timestamp > order.deadline) revert Expired();
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

    function getPosition(uint256 positionId) external view override returns (Position memory) {
        return positions[positionId];
    }

    function totalAllowance(address token) external view override returns (uint256) {
        return totalAllowances[token];
    }

    function vaultAddress() external view override returns (address) {
        return address(vault);
    }

    function _transferCollateral(Order memory order)
        internal
        validOrder(order)
        returns (
            uint256,
            uint256,
            address
        )
    {
        uint256 collateralPlaced = 0;
        IERC20 collateralToken;
        if (order.collateralIsSpentToken) collateralToken = IERC20(order.spentToken);
        else collateralToken = IERC20(order.obtainedToken);

        (, uint256 collateralReceived) = collateralToken.transferTokens(msg.sender, address(this), order.collateral);

        if (!order.collateralIsSpentToken)
            (collateralPlaced, ) = quote(order.spentToken, order.obtainedToken, collateralReceived);

        if (order.collateralIsSpentToken) {
            order.maxSpent -= collateralReceived;
            collateralPlaced = collateralReceived;
        }

        return (collateralReceived, collateralPlaced, address(collateralToken));
    }

    function openPosition(Order memory order) external returns (uint256) {
        address spentToken = order.spentToken;
        address obtainedToken = order.obtainedToken;
        uint256 riskFactor = computePairRiskFactor(spentToken, obtainedToken);

        (uint256 collateralReceived, uint256 collateralPlaced, address collateralToken) = _transferCollateral(order);
        uint256 toBorrow = order.maxSpent;
        uint256 toSpend = IERC20(spentToken).balanceOf(address(this));

        (uint256 interestRate, uint256 fees) = vault.borrow(
            spentToken,
            toBorrow,
            collateralPlaced,
            riskFactor,
            msg.sender
        );

        toSpend = IERC20(spentToken).balanceOf(address(this)) - toSpend;
        uint256 amountIn = _openPosition(order, toSpend, collateralReceived);

        if (amountIn < order.minObtained) revert Obtained_Insufficient_Amount(amountIn);

        positions[++id] = Position({
            owner: msg.sender,
            owedToken: spentToken,
            heldToken: obtainedToken,
            collateralToken: collateralToken,
            collateral: collateralReceived,
            principal: order.maxSpent,
            allowance: amountIn,
            interestRate: interestRate,
            fees: fees,
            createdAt: block.timestamp
        });

        emit PositionWasOpened(
            id,
            msg.sender,
            spentToken,
            obtainedToken,
            collateralToken,
            collateralReceived,
            toBorrow,
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
            (expectedCost, ) = quote(position.owedToken, position.heldToken, position.principal + position.fees);

        uint256 vaultRepaid = IERC20(position.owedToken).balanceOf(address(vault));
        (uint256 amountIn, uint256 amountOut) = _closePosition(position, expectedCost);

        if (collateralInHeldTokens && amountOut <= position.allowance)
            IERC20(position.heldToken).safeTransfer(position.owner, position.allowance - amountOut);

        vault.repay(position.owedToken, amountIn, position.principal, position.fees, position.owner);

        vaultRepaid = IERC20(position.owedToken).balanceOf(address(vault)) - vaultRepaid;

        if (vaultRepaid < position.principal) revert Loan_Not_Repaid(vaultRepaid, position.principal);

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
}
