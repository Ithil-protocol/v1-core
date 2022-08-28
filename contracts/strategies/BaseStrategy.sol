// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { IVault } from "../interfaces/IVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { PositionHelper } from "../libraries/PositionHelper.sol";
import { SVGImage } from "../libraries/SVGImage.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is Ownable, IStrategy, ERC721 {
    using SafeERC20 for IERC20;
    using PositionHelper for Position;
    using GeneralMath for uint256;

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

    modifier validOrder(Order calldata order) {
        if (block.timestamp > order.deadline) revert Strategy__Order_Expired(block.timestamp, order.deadline);
        if (order.spentToken == order.obtainedToken) revert Strategy__Source_Eq_Dest(order.spentToken);
        if (order.collateral == 0) revert Strategy__Insufficient_Collateral(order.collateral);
        _;

        vault.checkWhitelisted(order.spentToken);
    }

    modifier isPositionEditable(uint256 positionId) {
        if (ownerOf(positionId) != msg.sender) revert Strategy__Restricted_Access(ownerOf(positionId), msg.sender);

        // flashloan protection
        if (positions[positionId].createdAt == block.timestamp) revert Strategy__Action_Throttled();

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

    function openPosition(Order calldata order) external override validOrder(order) unlocked returns (uint256) {
        uint256 initialDstBalance = IERC20(order.obtainedToken).balanceOf(address(this));
        (uint256 interestRate, uint256 fees, uint256 toBorrow, address collateralToken) = _borrow(order);

        uint256 amountIn = _openPosition(order);

        if (!order.collateralIsSpentToken) amountIn += order.collateral;

        // slither-disable-next-line divide-before-multiply
        interestRate *=
            (toBorrow * (amountIn + 2 * initialDstBalance)) /
            (2 * order.collateral * (initialDstBalance + amountIn));

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
            fees: (fees * order.maxSpent) / VaultMath.RESOLUTION,
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
            fees,
            block.timestamp
        );

        _safeMint(msg.sender, id);

        return id;
    }

    function closePosition(uint256 positionId, uint256 maxOrMin) external override isPositionEditable(positionId) {
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
        if (
            (amountIn < maxOrMin && position.collateralToken != position.heldToken) ||
            (amountOut > maxOrMin && position.collateralToken != position.owedToken)
        ) revert Strategy__Insufficient_Amount_Out(amountIn, maxOrMin);
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

        emit PositionWasClosed(positionId, amountIn, amountOut, position.fees);
    }

    function editPosition(uint256 positionId, uint256 topUp) external override unlocked isPositionEditable(positionId) {
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

    function _resetApproval(IERC20 token, address receiver) internal {
        token.safeApprove(receiver, 0);
    }

    function _borrow(Order calldata order)
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
            toBorrow = order.maxSpent.positiveSub(order.collateral);
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
            profitAndLoss = SafeCast.toInt256(expectedTokens) - SafeCast.toInt256(position.principal + dueFees);
        } else {
            (expectedTokens, ) = quote(position.owedToken, position.heldToken, position.principal + dueFees);
            profitAndLoss = SafeCast.toInt256(position.allowance) - SafeCast.toInt256(expectedTokens);
        }

        score = SafeCast.toInt256(position.collateral * pairRiskFactor) - profitAndLoss * int24(VaultMath.RESOLUTION);
    }

    function forcefullyClose(
        uint256 positionId,
        address liquidatorUser,
        uint256 reward
    ) external override onlyLiquidator {
        Position memory position = positions[positionId];

        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            delete positions[positionId];
            _burn(positionId);
            uint256 maxOrMin = 0;
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;
            if (collateralInHeldTokens) maxOrMin = position.allowance;
            else (maxOrMin, ) = quote(position.heldToken, position.owedToken, position.allowance);
            (uint256 amountIn, uint256 amountOut) = _closePosition(position, maxOrMin);
            // Computation of reward is done by adding to the dueFees
            dueFees +=
                ((amountIn.positiveSub(position.principal + dueFees)) * (VaultMath.RESOLUTION - reward)) /
                VaultMath.RESOLUTION;

            // In a bad liquidation event, 5% of the paid amount is transferred
            // Linearly scales with reward (with 0 reward corresponding to 0 transfer)
            // A direct transfer is needed since repay does not transfer anything
            // The check is done *after* the repay because surely the vault has the balance

            // If position.principal + dueFees < amountIn < 20 * (position.principal + dueFees) / 19
            // then amountIn / 20 > amountIn - principal - dueFees and the liquidator may be better off
            // not liquidating the position and instead wait for it to become bad liquidation
            if (amountIn < (20 * (position.principal + dueFees)) / 19)
                amountIn -= (amountIn * reward) / (20 * VaultMath.RESOLUTION);

            vault.repay(
                position.owedToken,
                amountIn,
                position.principal,
                dueFees,
                riskFactors[position.heldToken],
                liquidatorUser
            );

            emit PositionWasLiquidated(positionId);
        } else revert Strategy__Position_Not_Liquidable(positionId, score);
    }

    function transferAllowance(
        uint256 positionId,
        uint256 price,
        address liquidatorUser,
        uint256 reward
    ) external override onlyLiquidator {
        Position memory position = positions[positionId];
        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            delete positions[positionId];
            uint256 fairPrice = 0;
            // This is the market price of the position's allowance in owedTokens
            // No need to distinguish between collateral in held tokens or not
            (fairPrice, ) = quote(position.heldToken, position.owedToken, position.allowance);
            fairPrice += dueFees;
            // Apply discount based on reward (max 5%)
            // In this case there is no distinction between good or bad liquidation
            fairPrice -= (fairPrice * reward) / (VaultMath.RESOLUTION * 20);
            if (price < fairPrice) revert Strategy__Insufficient_Amount_Out(price, fairPrice);
            else {
                IERC20(position.owedToken).safeTransferFrom(liquidatorUser, address(vault), price);
                IERC20(position.heldToken).safeTransfer(liquidatorUser, position.allowance);
                // The following is necessary to avoid residual transfers during the repay
                // It means that everything "extra" from principal is fees
                dueFees = price.positiveSub(position.principal);
            }
            vault.repay(
                position.owedToken,
                price,
                position.principal,
                dueFees,
                riskFactors[position.heldToken],
                liquidatorUser
            );
            _burn(positionId);

            emit PositionWasLiquidated(positionId);
        } else revert Strategy__Position_Not_Liquidable(positionId, score);
    }

    function modifyCollateralAndOwner(
        uint256 positionId,
        uint256 newCollateral,
        address liquidatorUser,
        uint256 reward
    ) external override onlyLiquidator {
        Position storage position = positions[positionId];
        (int256 score, uint256 dueFees) = computeLiquidationScore(position);
        if (score > 0) {
            _transfer(ownerOf(positionId), liquidatorUser, positionId);
            // reduce due fees based on reward (max 50%)
            position.fees += (dueFees * (2 * VaultMath.RESOLUTION - reward)) / (2 * VaultMath.RESOLUTION);
            position.createdAt = block.timestamp;
            bool collateralInOwedToken = position.collateralToken != position.heldToken;
            if (collateralInOwedToken)
                vault.repay(
                    position.owedToken,
                    newCollateral,
                    newCollateral,
                    0,
                    riskFactors[position.heldToken],
                    liquidatorUser
                );
            position.topUpCollateral(
                liquidatorUser,
                collateralInOwedToken ? address(vault) : address(this),
                newCollateral,
                collateralInOwedToken
            );
            (int256 newScore, ) = computeLiquidationScore(position);
            if (newScore > 0) revert Strategy__Insufficient_Margin_Provided(newScore);
        } else revert Strategy__Position_Not_Liquidable(positionId, score);
    }

    // Abstract strategy

    function _openPosition(Order calldata order) internal virtual returns (uint256);

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
        assert(_exists(tokenId));

        Position storage position = positions[tokenId];
        (int256 score, ) = computeLiquidationScore(position);

        return
            SVGImage.generateMetadata(
                name(),
                symbol(),
                tokenId,
                position.collateralToken,
                position.collateral,
                position.createdAt,
                score
            );
    }
}
