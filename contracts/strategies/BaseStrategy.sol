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

    function vaultAddress() external view override returns (address) {
        return address(vault);
    }

    function _transferCollateral(Order memory order)
        internal
        validOrder(order)
        returns (
            uint256 collateralReceived,
            uint256 toBorrow,
            address collateralToken,
            uint256 originalCollBal
        )
    {
        toBorrow = order.maxSpent;
        if (order.collateralIsSpentToken) {
            collateralToken = order.spentToken;
            (originalCollBal, collateralReceived) = IERC20(collateralToken).transferTokens(
                msg.sender,
                address(this),
                order.collateral
            );
            toBorrow -= collateralReceived;
        } else {
            collateralToken = order.obtainedToken;
            (originalCollBal, collateralReceived) = IERC20(collateralToken).transferTokens(
                msg.sender,
                address(this),
                order.collateral
            );
        }
    }

    function openPosition(Order memory order) external returns (uint256) {
        (
            uint256 interestRate,
            uint256 fees,
            uint256 toSpend,
            uint256 collateralReceived,
            uint256 toBorrow,
            address collateralToken
        ) = _borrow(order);

        toSpend = IERC20(order.spentToken).balanceOf(address(this)) - toSpend;
        if (order.collateralIsSpentToken) {
            order.maxSpent = toSpend + collateralReceived;
            interestRate *= toBorrow / collateralReceived;
        }
        uint256 amountIn = _openPosition(order);
        if (!order.collateralIsSpentToken) {
            amountIn += collateralReceived;
            interestRate *= amountIn / collateralReceived;
        }

        if (interestRate > VaultMath.MAX_RATE) revert Maximum_Leverage_Exceeded();

        if (amountIn < order.minObtained) revert Obtained_Insufficient_Amount(amountIn);

        positions[++id] = Position({
            owner: msg.sender,
            owedToken: order.spentToken,
            heldToken: order.obtainedToken,
            collateralToken: collateralToken,
            collateral: collateralReceived,
            principal: toBorrow,
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
            collateralToken,
            collateralReceived,
            toBorrow,
            amountIn,
            interestRate,
            block.timestamp
        );

        return id;
    }

    function closePosition(uint256 positionId, uint256 maxOrMin) external validPosition(positionId) {
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

        bool collateralInHeldTokens = position.collateralToken != position.owedToken;

        uint256 vaultRepaid = IERC20(position.owedToken).balanceOf(address(vault));
        (uint256 amountIn, uint256 amountOut) = _closePosition(position, maxOrMin);
        _repay(position, amountIn);

        if (collateralInHeldTokens && amountOut <= position.allowance)
            IERC20(position.heldToken).safeTransfer(position.owner, position.allowance - amountOut);

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

    function _maxApprove(IERC20 token, address receiver) internal {
        if (token.allowance(address(this), receiver) <= 0) {
            token.safeApprove(receiver, type(uint256).max);
        }
    }

    function _borrow(Order memory order)
        internal
        returns (
            uint256 interestRate,
            uint256 fees,
            uint256 toSpend,
            uint256 collateralReceived,
            uint256 toBorrow,
            address collateralToken
        )
    {
        address spentToken = order.spentToken;
        address obtainedToken = order.obtainedToken;
        uint256 riskFactor = computePairRiskFactor(spentToken, obtainedToken);
        uint256 originalCollBal = 0;

        uint256 netLoans = vault.state(spentToken).netLoans;

        riskFactors[obtainedToken] += (riskFactors[obtainedToken] * order.maxSpent) / (netLoans + order.maxSpent);

        (collateralReceived, toBorrow, collateralToken, originalCollBal) = _transferCollateral(order);
        toSpend = originalCollBal + collateralReceived;
        if (!order.collateralIsSpentToken) {
            toSpend = IERC20(spentToken).balanceOf(address(this));
        }

        (interestRate, fees) = vault.borrow(spentToken, toBorrow, riskFactor, msg.sender);
    }

    function _repay(Position memory position, uint256 amountIn) internal {
        uint256 netLoans = vault.state(position.owedToken).netLoans;

        riskFactors[position.heldToken] -= (riskFactors[position.heldToken] * position.principal) / netLoans;

        vault.repay(position.owedToken, amountIn, position.principal, position.fees, position.owner);
    }
}
