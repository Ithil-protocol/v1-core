// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { IVault } from "../interfaces/IVault.sol";
import { ISVGImageGenerator } from "../interfaces/ISVGImageGenerator.sol";
import { IInterestRateModel } from "../interfaces/IInterestRateModel.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { PositionHelper } from "../libraries/PositionHelper.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is Ownable, IStrategy, ERC721 {
    using SafeERC20 for IERC20;
    using PositionHelper for Position;
    using GeneralMath for uint256;

    address public immutable liquidator;
    IVault public immutable override vault;
    mapping(uint256 => Position) public positions;
    uint256 public id;
    bool public locked;
    address public guardian;
    mapping(address => uint256) public riskFactors;
    ISVGImageGenerator public immutable generator;
    IInterestRateModel public immutable interestRateModel;

    constructor(
        address _vault,
        address _liquidator,
        address _generator,
        address _interestRateModel,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        liquidator = _liquidator;
        vault = IVault(_vault);
        generator = ISVGImageGenerator(_generator);
        interestRateModel = IInterestRateModel(_interestRateModel);
        id = 0;
        locked = false;
    }

    modifier isPositionEditable(uint256 positionId) {
        if (msg.sender != ownerOf(positionId) && msg.sender != liquidator) revert Strategy__Restricted_Access();

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

    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert Strategy__Only_Liquidator();
        _;
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
    }

    function setRiskFactor(address token, uint256 riskFactor) external onlyOwner {
        if (riskFactor > GeneralMath.RESOLUTION) revert Strategy__Too_High_Risk();
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

    function openPositionWithPermit(
        Order calldata order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override returns (uint256) {
        IERC20Permit permitToken = IERC20Permit(order.spentToken);
        SafeERC20.safePermit(permitToken, msg.sender, address(this), order.maxSpent, order.deadline, v, r, s);

        return openPosition(order);
    }

    function openPosition(Order calldata order) public override unlocked returns (uint256) {
        if (block.timestamp > order.deadline) revert Strategy__Order_Expired();
        if (order.spentToken == order.obtainedToken) revert Strategy__Source_Eq_Dest();
        if (order.collateral == 0) revert Strategy__Insufficient_Collateral();

        vault.checkWhitelisted(order.spentToken);

        uint256 initialExposure = exposure(order.obtainedToken);
        (uint256 interestRate, uint256 fees, uint256 riskFactor, uint256 toBorrow, address collateralToken) = _borrow(
            order
        );

        uint256 amountIn = _openPosition(order);
        if (!order.collateralIsSpentToken) amountIn += order.collateral;
        if (amountIn < order.minObtained) revert Strategy__Insufficient_Amount_Out();

        interestRate = interestRateModel.computeIR(interestRate, toBorrow, amountIn, initialExposure, order.collateral);

        positions[++id] = Position({
            lender: address(vault),
            owedToken: order.spentToken,
            heldToken: order.obtainedToken,
            collateralToken: collateralToken,
            collateral: order.collateral,
            principal: toBorrow,
            allowance: amountIn,
            interestRate: interestRate,
            riskFactor: riskFactor,
            fees: (fees * order.maxSpent) / GeneralMath.RESOLUTION,
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

        position.fees += interestRateModel.computeTimeFees(
            position.principal,
            position.interestRate,
            block.timestamp - position.createdAt
        );

        (uint256 amountIn, uint256 amountOut) = _closePosition(position, maxOrMin);
        if (
            (amountIn < maxOrMin && position.collateralToken != position.heldToken) ||
            (amountOut > maxOrMin && position.collateralToken != position.owedToken)
        ) revert Strategy__Insufficient_Amount_Out();
        uint256 repaid = vault.repay(
            position.owedToken,
            amountIn,
            position.principal,
            position.fees,
            position.riskFactor,
            owner
        );
        if (position.collateralToken != position.owedToken && amountOut <= position.allowance)
            IERC20(position.heldToken).safeTransfer(owner, position.allowance - amountOut);

        /// The following check is important to prevent users from triggering bad liquidations
        if (amountIn - repaid < position.principal + position.fees) revert Strategy__Loan_Not_Repaid();

        emit PositionWasClosed(positionId, amountIn, amountOut, position.fees);
    }

    function editPosition(uint256 positionId, uint256 topUp) external override unlocked isPositionEditable(positionId) {
        Position storage position = positions[positionId];

        position.topUpCollateral(
            ownerOf(positionId),
            position.collateralToken == position.owedToken ? position.lender : address(this),
            topUp,
            position.collateralToken == position.owedToken
        );
    }

    function _borrow(Order calldata order)
        internal
        returns (
            uint256 interestRate,
            uint256 fees,
            uint256 riskFactor,
            uint256 toBorrow,
            address collateralToken
        )
    {
        uint256 risk0 = riskFactors[order.spentToken];
        uint256 risk1 = riskFactors[order.obtainedToken];
        riskFactor = interestRateModel.computePairRiskFactor(risk0, risk1);

        if (order.collateralIsSpentToken) {
            collateralToken = order.spentToken;
            toBorrow = order.maxSpent.positiveSub(order.collateral);
        } else {
            collateralToken = order.obtainedToken;
            toBorrow = order.maxSpent;
        }

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), order.collateral);
        if (order.collateral < vault.getMinimumMargin(collateralToken)) revert Strategy__Margin_Below_Minimum();

        (interestRate, fees) = vault.borrow(order.spentToken, toBorrow, riskFactor, msg.sender);
    }

    // Only liquidator

    function deleteAndBurn(uint256 positionId) external override onlyLiquidator {
        delete positions[positionId];
        _burn(positionId);
        emit PositionWasLiquidated(positionId);
    }

    function approveAllowance(Position memory position) external override onlyLiquidator {
        IERC20(position.heldToken).approve(liquidator, type(uint256).max);
    }

    function directClosure(Position memory position, uint256 maxOrMin)
        external
        override
        onlyLiquidator
        returns (uint256)
    {
        (uint256 amountIn, ) = _closePosition(position, maxOrMin);
        return amountIn;
    }

    function directRepay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        uint256 riskFactor,
        address borrower
    ) external override onlyLiquidator {
        vault.repay(token, amount, debt, fees, riskFactor, borrower);
    }

    function transferNFT(uint256 positionId, address newOwner) external override onlyLiquidator {
        address oldOwner = ownerOf(positionId);
        _transfer(oldOwner, newOwner, positionId);
        emit PositionChangedOwner(positionId, oldOwner, newOwner);
    }

    /// @dev must be reviewed
    function securitisePosition(uint256 positionID, address newLender) external onlyOwner {
        Position memory position = positions[positionID];
        position.fees += interestRateModel.computeTimeFees(
            position.principal,
            position.interestRate,
            block.timestamp - position.createdAt
        );

        IERC20(position.owedToken).safeTransferFrom(msg.sender, position.lender, position.principal + position.fees);
        positions[positionID].lender = newLender;
    }

    // Abstract strategy

    function _openPosition(Order calldata order) internal virtual returns (uint256);

    // Implementation rule: the amountOut must be transferred to the vault
    function _closePosition(Position memory position, uint256 maxOrMin) internal virtual returns (uint256, uint256);

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view virtual override returns (uint256, uint256);

    function exposure(address token) public view virtual returns (uint256);

    // slither-disable-next-line external-function
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        assert(_exists(tokenId));

        (bool success, bytes memory data) = liquidator.staticcall(
            abi.encodeWithSignature("computeLiquidationScore(address,uint256)", address(this), tokenId)
        );
        assert(success);
        int256 score = abi.decode(data, (int256));

        Position memory position = positions[tokenId];

        return
            ISVGImageGenerator(generator).generateMetadata(
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
