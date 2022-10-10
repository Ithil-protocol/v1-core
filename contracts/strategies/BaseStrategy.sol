// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { IVault } from "../interfaces/IVault.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { SVGImage } from "../libraries/SVGImage.sol";

/// @title    BaseStrategy contract
/// @author   Ithil
/// @notice   Base contract to inherit to keep status updates consistent
abstract contract BaseStrategy is Ownable, IStrategy, ERC721 {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    address public immutable liquidator;
    IVault public immutable override vault;
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
        if (msg.sender != ownerOf(positionId) && msg.sender != liquidator)
            revert Strategy__Restricted_Access(ownerOf(positionId), msg.sender);

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
        if (msg.sender != liquidator) revert Strategy__Only_Liquidator(msg.sender, liquidator);
        _;
    }

    modifier validRisk(uint256 riskFactor) {
        if (riskFactor > VaultMath.RESOLUTION) revert Strategy__Too_High_Risk(riskFactor);
        _;
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
    }

    function setRiskFactor(address token, uint256 riskFactor) external onlyOwner validRisk(riskFactor) {
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

    function computePairRiskFactor(address token0, address token1) public view override returns (uint256) {
        uint256 risk0 = riskFactors[token0];
        uint256 risk1 = riskFactors[token1];
        if (risk0 == 0 || risk1 == 0) revert Strategy__Unsupported_Token(token0, token1);
        return (risk0 + risk1) / 2;
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

    function openPosition(Order calldata order) public override validOrder(order) unlocked returns (uint256) {
        uint256 initialExposure = exposure(order.obtainedToken);
        (uint256 interestRate, uint256 fees, uint256 riskFactor, uint256 toBorrow, address collateralToken) = _borrow(
            order
        );

        uint256 amountIn = _openPosition(order);

        if (amountIn < order.minObtained) revert Strategy__Insufficient_Amount_Out(amountIn, order.minObtained);

        if (!order.collateralIsSpentToken) {
            interestRate *= (amountIn * (amountIn + 2 * initialExposure));
            amountIn += order.collateral;
        } else interestRate *= (toBorrow * (amountIn + 2 * initialExposure));

        interestRate /= (2 * order.collateral * (initialExposure + amountIn));

        if (interestRate > VaultMath.MAX_RATE) revert Strategy__Maximum_Leverage_Exceeded(interestRate);

        positions[++id] = Position({
            owedToken: order.spentToken,
            heldToken: order.obtainedToken,
            collateralToken: collateralToken,
            collateral: order.collateral,
            principal: toBorrow,
            allowance: amountIn,
            interestRate: interestRate,
            riskFactor: riskFactor,
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

        (uint256 amountIn, uint256 amountOut) = _closePosition(position, maxOrMin);
        if (
            (amountIn < maxOrMin && position.collateralToken != position.heldToken) ||
            (amountOut > maxOrMin && position.collateralToken != position.owedToken)
        ) revert Strategy__Insufficient_Amount_Out(amountIn, maxOrMin);
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
        if (amountIn - repaid < position.principal + position.fees)
            revert Strategy__Loan_Not_Repaid(amountIn - repaid, position.principal + position.fees);

        emit PositionWasClosed(positionId, amountIn, amountOut, position.fees);
    }

    function editPosition(uint256 positionId, uint256 topUp) external override unlocked isPositionEditable(positionId) {
        Position storage position = positions[positionId];

        if (position.collateralToken == position.owedToken) {
            position.principal -= topUp;
        } else {
            position.allowance += topUp;
        }

        address to = position.collateralToken == position.owedToken ? address(vault) : address(this);
        IERC20(position.collateralToken).safeTransferFrom(ownerOf(positionId), to, topUp);

        emit PositionWasToppedUp(positionId, topUp);
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
        riskFactor = computePairRiskFactor(order.spentToken, order.obtainedToken);

        if (order.collateralIsSpentToken) {
            collateralToken = order.spentToken;
            toBorrow = order.maxSpent.positiveSub(order.collateral);
        } else {
            collateralToken = order.obtainedToken;
            toBorrow = order.maxSpent;
        }

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), order.collateral);

        if (order.collateral < vault.getMinimumMargin(collateralToken))
            revert Strategy__Margin_Below_Minimum(order.collateral, vault.getMinimumMargin(collateralToken));

        (interestRate, fees) = vault.borrow(order.spentToken, toBorrow, riskFactor, msg.sender);
    }

    function _maxApprove(IERC20 token, address dest) internal {
        if (token.allowance(address(this), dest) == 0) token.approve(dest, type(uint256).max);
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
