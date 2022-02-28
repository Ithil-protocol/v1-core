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
    address public immutable liquidator;
    uint256 public id;
    mapping(address => uint256) public riskFactors;
    mapping(uint256 => Position) public positions;
    mapping(address => uint256) public totalAllowances;

    constructor(address _vault, address _liquidator) {
        vault = IVault(_vault);
        liquidator = _liquidator;
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

    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert Only_Liquidator(msg.sender, liquidator);
        _;
    }

    function setRiskFactor(address token, uint256 riskFactor) external onlyOwner {
        riskFactors[token] = riskFactor;
    }

    function getPosition(uint256 positionId) public view override returns (Position memory) {
        return positions[positionId];
    }

    function totalAllowance(address token) external view override returns (uint256) {
        return totalAllowances[token];
    }

    function computePairRiskFactor(address token0, address token1) public view override returns (uint256) {
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
            (collateralPlaced, ) = quote(order.spentToken, order.obtainedToken, collateralReceived);

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
            (expectedCost, ) = quote(position.owedToken, position.heldToken, position.principal + position.fees);

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

    function forcefullyClose(Position memory position, uint256 expectedCost) external override onlyLiquidator {
        _closePosition(position, expectedCost);
    }

    function forcefullyDelete(uint256 _id) external override onlyLiquidator {
        Position memory position = positions[_id];
        delete positions[_id];
        if (totalAllowances[position.heldToken] > 0) totalAllowances[position.heldToken] -= position.allowance;
        emit PositionWasLiquidated(_id);
    }

    function modifyCollateralAndOwner(
        uint256 _id,
        uint256 newCollateral,
        address newOwner
    ) external override onlyLiquidator {
        positions[_id].collateral += newCollateral;
        positions[_id].owner = newOwner;
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

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view virtual override returns (uint256, uint256);
}
