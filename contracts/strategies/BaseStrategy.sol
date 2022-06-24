// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { LiquidableStrategy } from "./LiquidableStrategy.sol";
import { PositionHelper } from "../libraries/PositionHelper.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is LiquidableStrategy {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;
    using PositionHelper for Position;

    uint256 public id;
    bool public locked;
    address public guardian;

    constructor(
        address _vault,
        address _liquidator,
        string memory _name,
        string memory _symbol
    ) LiquidableStrategy(_liquidator, _vault, _name, _symbol) {
        id = 0;
        locked = false;
    }

    modifier validOrder(Order memory order) {
        if (block.timestamp > order.deadline) revert Strategy__Order_Expired(block.timestamp, order.deadline);
        if (order.spentToken == order.obtainedToken) revert Strategy__Source_Eq_Dest(order.spentToken);
        if (order.collateral == 0) revert Strategy__Insufficient_Collateral(order.collateral);
        _;

        vault.checkWhitelisted(order.spentToken);
        vault.checkWhitelisted(order.obtainedToken);
    }

    modifier isPositionEditable(uint256 positionId) {
        if (ownerOf(positionId) != msg.sender) revert Strategy__Restricted_Access(ownerOf(positionId), msg.sender);

        // flashloan protection
        if (positions[positionId].createdAt >= block.timestamp)
            revert Strategy__Throttled(positions[positionId].createdAt, block.timestamp);

        _;
    }

    modifier unlocked() {
        if (locked) revert Strategy__Locked();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert Strategy__Only_Guardian();
        _;
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
    }

    function setRiskFactor(address token, uint256 riskFactor) external onlyOwner {
        riskFactors[token] = riskFactor;
    }

    function toggleLock(bool _locked) external onlyGuardian {
        locked = _locked;

        emit StrategyLockWasToggled(locked);
    }

    function getPosition(uint256 positionId) external view override returns (Position memory) {
        return positions[positionId];
    }

    function vaultAddress() external view override returns (address) {
        return address(vault);
    }

    function openPosition(Order memory order) external validOrder(order) unlocked returns (uint256) {
        (
            uint256 interestRate,
            uint256 fees,
            uint256 toSpend,
            uint256 collateralReceived,
            uint256 toBorrow,
            address collateralToken
        ) = _borrow(order);

        if (order.collateralIsSpentToken) order.maxSpent = toSpend + collateralReceived;

        uint256 amountIn;
        if (!order.collateralIsSpentToken) {
            amountIn = _openPosition(order);
            amountIn += collateralReceived;
            interestRate *= amountIn / collateralReceived;
        } else {
            uint256 initialDstBalance = IERC20(order.obtainedToken).balanceOf(address(this));
            amountIn = _openPosition(order);
            interestRate *= (toBorrow * initialDstBalance) / (collateralReceived * (initialDstBalance + amountIn));
        }

        if (interestRate > VaultMath.MAX_RATE) revert Strategy__Maximum_Leverage_Exceeded(interestRate);

        if (amountIn < order.minObtained) revert Strategy__Insufficient_Amount_Out(amountIn, order.minObtained);

        positions[++id] = Position({
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

        _safeMint(msg.sender, id);

        return id;
    }

    function closePosition(uint256 positionId, uint256 maxOrMin) external isPositionEditable(positionId) {
        Position memory position = positions[positionId];
        address owner = ownerOf(positionId);
        delete positions[positionId];
        _burn(positionId);

        position.fees += VaultMath.computeTimeFees(
            position.principal,
            position.interestRate,
            block.timestamp - position.createdAt
        );

        IERC20 owedToken = IERC20(position.owedToken);
        uint256 vaultRepaid = owedToken.balanceOf(address(vault));
        (uint256 amountIn, uint256 amountOut) = _closePosition(position, maxOrMin);
        vault.repay(
            position.owedToken,
            amountIn,
            position.principal,
            position.fees,
            riskFactors[position.heldToken],
            owner
        );

        if (position.collateralToken != position.owedToken && amountOut <= position.allowance)
            IERC20(position.heldToken).safeTransfer(owner, position.allowance - amountOut);

        vaultRepaid = owedToken.balanceOf(address(vault)) - vaultRepaid;

        /// The following check is important to prevent users from triggering bad liquidations
        if (vaultRepaid < position.principal) revert Strategy__Loan_Not_Repaid(vaultRepaid, position.principal);

        emit PositionWasClosed(positionId);
    }

    function editPosition(uint256 positionId, uint256 newCollateral) external unlocked isPositionEditable(positionId) {
        Position storage position = positions[positionId];

        position.topUpCollateral(
            msg.sender,
            position.collateralToken == position.owedToken ? address(vault) : address(this),
            newCollateral
        );
    }

    function _maxApprove(IERC20 token, address receiver) internal {
        if (token.allowance(address(this), receiver) <= 0) {
            token.safeApprove(receiver, 0);
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
        IERC20 spentTkn = IERC20(spentToken);
        address obtainedToken = order.obtainedToken;
        uint256 riskFactor = computePairRiskFactor(spentToken, obtainedToken);
        uint256 originalCollBal = 0;

        collateralToken = order.collateralIsSpentToken ? order.spentToken : order.obtainedToken;

        (collateralReceived, toBorrow, originalCollBal) = IERC20(collateralToken).transferAsCollateral(order);

        if (collateralReceived < vault.getMinimumMargin(spentToken))
            revert Strategy__Margin_Below_Minimum(collateralReceived, vault.getMinimumMargin(spentToken));

        toSpend = originalCollBal + collateralReceived;
        if (!order.collateralIsSpentToken) {
            toSpend = spentTkn.balanceOf(address(this));
        }

        (interestRate, fees) = vault.borrow(spentToken, toBorrow, riskFactor, msg.sender);
        toSpend = spentTkn.balanceOf(address(this)) - toSpend;
    }
}
