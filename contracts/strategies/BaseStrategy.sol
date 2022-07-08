// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { IVault } from "../interfaces/IVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { PositionHelper } from "../libraries/PositionHelper.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is Ownable, IStrategy, ERC721 {
    using SafeERC20 for IERC20;
    using PositionHelper for Position;

    address public immutable liquidator;
    IVault public immutable vault;
    mapping(uint256 => Position) public positions;
    uint256 public id;
    bool public locked;
    address public guardian;
    mapping(address => uint256) public riskFactors;

    constructor(
        address _vault,
        address _liquidator,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        liquidator = _liquidator;
        vault = IVault(_vault);
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

        emit RiskFactorWasUpdated(token, riskFactor);
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
        (uint256 interestRate, uint256 fees, uint256 toBorrow, address collateralToken) = _borrow(order);

        uint256 amountIn;
        if (!order.collateralIsSpentToken) {
            amountIn = _openPosition(order);
            amountIn += order.collateral;

            // slither-disable-next-line divide-before-multiply
            interestRate *= amountIn / order.collateral;
        } else {
            uint256 initialDstBalance = IERC20(order.obtainedToken).balanceOf(address(this));
            amountIn = _openPosition(order);

            // slither-disable-next-line divide-before-multiply
            interestRate *= (toBorrow * initialDstBalance) / (order.collateral * (initialDstBalance + amountIn));
        }

        if (interestRate > VaultMath.MAX_RATE) revert Strategy__Maximum_Leverage_Exceeded(interestRate);

        if (amountIn < order.minObtained) revert Strategy__Insufficient_Amount_Out(amountIn, order.minObtained);

        positions[++id] = Position({
            owedToken: order.spentToken,
            heldToken: order.obtainedToken,
            collateralToken: collateralToken,
            collateral: order.collateral,
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
            order.collateral,
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
        if (vaultRepaid < position.principal + position.fees)
            revert Strategy__Loan_Not_Repaid(vaultRepaid, position.principal + position.fees);

        emit PositionWasClosed(positionId);
    }

    function editPosition(uint256 positionId, uint256 topUp) external unlocked isPositionEditable(positionId) {
        Position storage position = positions[positionId];

        position.topUpCollateral(
            msg.sender,
            position.collateralToken == position.owedToken ? address(vault) : address(this),
            topUp,
            position.collateralToken == position.owedToken
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
            uint256 toBorrow,
            address collateralToken
        )
    {
        uint256 riskFactor = computePairRiskFactor(order.spentToken, order.obtainedToken);

        if (order.collateralIsSpentToken) {
            collateralToken = order.spentToken;
            toBorrow = order.maxSpent - order.collateral;
        } else {
            collateralToken = order.obtainedToken;
            toBorrow = order.maxSpent;
        }

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), order.collateral);

        if (order.collateral < vault.getMinimumMargin(order.spentToken))
            revert Strategy__Margin_Below_Minimum(order.collateral, vault.getMinimumMargin(order.spentToken));

        (interestRate, fees) = vault.borrow(order.spentToken, toBorrow, riskFactor, msg.sender);
    }

    // Liquidator

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
            IERC20(position.owedToken).safeTransferFrom(purchaser, address(vault), price);
            if (price < position.principal + dueFees)
                revert Strategy__Insufficient_Amount_Out(price, position.principal + dueFees);
            else IERC20(position.heldToken).safeTransfer(purchaser, position.allowance);
            vault.repay(
                position.owedToken,
                price,
                position.principal,
                dueFees,
                riskFactors[position.heldToken],
                purchaser
            );
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

    // Abstract strategy

    function _openPosition(Order memory order) internal virtual returns (uint256);

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        virtual
        returns (uint256 amountIn, uint256 amountOut);

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view virtual override returns (uint256, uint256);

    // slither-disable-next-line external-function
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId));
        return ""; /// @todo generate SVG on-chain
    }
}
