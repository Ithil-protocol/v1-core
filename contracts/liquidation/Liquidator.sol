// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";

import "hardhat/console.sol";

/// @title    Liquidator contract
/// @author   Ithil
/// @notice   Base liquidation contract, can forcefully close base strategy's positions
contract Liquidator is Ownable {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    IERC20 public rewardToken;
    mapping(address => mapping(address => uint256)) public stakes;
    // maximumStake is always denominated in rewardToken
    uint256 public maximumStake;

    error Liquidator__Not_Enough_Ithil_Allowance(uint256 allowance);
    error Liquidator__Not_Enough_Ithil();
    error Liquidator__Unstaking_Too_Much(uint256 maximum);

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function setMaximumStake(uint256 amount) external onlyOwner {
        maximumStake = amount;
    }

    function setToken(address token) external onlyOwner {
        rewardToken = IERC20(token);
    }

    // The rewardToken only can be staked
    function stake(uint256 amount) external {
        uint256 allowance = rewardToken.allowance(msg.sender, address(this));
        if (rewardToken.balanceOf(msg.sender) < amount) revert Liquidator__Not_Enough_Ithil();
        if (allowance < amount) revert Liquidator__Not_Enough_Ithil_Allowance(allowance);
        stakes[address(rewardToken)][msg.sender] += amount;
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // When the token changes, people must be able to unstake the old one
    function unstake(address token, uint256 amount) external {
        uint256 staked = stakes[token][msg.sender];
        if (staked < amount) revert Liquidator__Unstaking_Too_Much(staked);
        stakes[token][msg.sender] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function liquidateSingle(address _strategy, uint256 positionId) external {
        uint256 reward = rewardPercentage();
        IStrategy strategy = IStrategy(_strategy);
        _forcefullyClose(strategy, positionId, msg.sender, reward);
    }

    function marginCall(
        address _strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        uint256 reward = rewardPercentage();
        IStrategy strategy = IStrategy(_strategy);
        _modifyCollateralAndOwner(strategy, positionId, extraMargin, msg.sender, reward);
    }

    function purchaseAssets(
        address _strategy,
        uint256 positionId,
        uint256 price
    ) external {
        uint256 reward = rewardPercentage();
        IStrategy strategy = IStrategy(_strategy);
        _transferAllowance(strategy, positionId, price, msg.sender, reward);
    }

    // rewardPercentage is computed as of the stakes of rewardTokens
    function rewardPercentage() public view returns (uint256) {
        if (maximumStake > 0) {
            uint256 stakePercentage = (stakes[address(rewardToken)][msg.sender] * VaultMath.RESOLUTION) / maximumStake;
            if (stakePercentage > VaultMath.RESOLUTION) return VaultMath.RESOLUTION;
            else return stakePercentage;
        } else {
            return 0;
        }
    }

    // Liquidator

    function liqScoreByAddressAndId(address _strategy, uint256 _positionId) public view returns (int256) {
        IStrategy.Position memory position = IStrategy(_strategy).getPosition(_positionId);
        (int256 score, ) = computeLiquidationScore(_strategy, position);
        return score;
    }

    function computeLiquidationScore(address _strategy, IStrategy.Position memory position)
        public
        view
        returns (int256, uint256)
    {
        IStrategy strategy = IStrategy(_strategy);
        bool collateralInOwedToken = position.collateralToken != position.heldToken;
        uint256 expectedTokens;
        int256 profitAndLoss;

        uint256 dueFees = position.fees +
            (position.interestRate * (block.timestamp - position.createdAt) * position.principal) /
            (uint32(VaultMath.TIME_FEE_PERIOD) * VaultMath.RESOLUTION);

        if (collateralInOwedToken) {
            (expectedTokens, ) = strategy.quote(position.heldToken, position.owedToken, position.allowance);
            profitAndLoss = SafeCast.toInt256(expectedTokens) - SafeCast.toInt256(position.principal + dueFees);
        } else {
            (expectedTokens, ) = strategy.quote(position.owedToken, position.heldToken, position.principal + dueFees);
            profitAndLoss = SafeCast.toInt256(position.allowance) - SafeCast.toInt256(expectedTokens);
        }

        int256 score = SafeCast.toInt256(position.collateral * position.riskFactor) -
            profitAndLoss *
            int24(VaultMath.RESOLUTION);

        return (score, dueFees);
    }

    /// @notice liquidation method: forcefully close a position and repays the vault and the liquidator
    /// @param positionId the id of the position to be closed
    /// @param liquidatorUser the address of the user performing the liquidation
    /// @param reward the liquidator's reward ratio
    function _forcefullyClose(
        IStrategy strategy,
        uint256 positionId,
        address liquidatorUser,
        uint256 reward
    ) internal {
        IStrategy.Position memory position = strategy.getPosition(positionId);

        (int256 score, uint256 dueFees) = computeLiquidationScore(address(strategy), position);
        if (score > 0) {
            strategy.deleteAndBurn(positionId);
            uint256 maxOrMin = 0;
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;
            if (collateralInHeldTokens) {
                maxOrMin = position.allowance;
            } else {
                (maxOrMin, ) = strategy.quote(position.heldToken, position.owedToken, position.allowance);
            }

            uint256 amountIn = strategy.directClosure(position, maxOrMin);

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

            strategy.directRepay(
                position.owedToken,
                amountIn,
                position.principal,
                dueFees,
                position.riskFactor,
                liquidatorUser
            );
        } else {
            revert Liquidator__Position_Not_Liquidable(positionId, score);
        }
    }

    /// @notice liquidation method: transfers the allowance to the liquidator after
    ///         the liquidator repays the debt with the vault
    /// @param positionId the id of the position to be closed
    /// @param price the amount transferred to the vault by the liquidator
    /// @param liquidatorUser the address of the user performing the liquidation
    /// @param reward the liquidator's reward ratio
    function _transferAllowance(
        IStrategy strategy,
        uint256 positionId,
        uint256 price,
        address liquidatorUser,
        uint256 reward
    ) internal {
        IStrategy.Position memory position = strategy.getPosition(positionId);
        (int256 score, uint256 dueFees) = computeLiquidationScore(address(strategy), position);
        if (score > 0) {
            strategy.deleteAndBurn(positionId);
            uint256 fairPrice = 0;
            // This is the market price of the position's allowance in owedTokens
            // No need to distinguish between collateral in held tokens or not
            (fairPrice, ) = strategy.quote(position.heldToken, position.owedToken, position.allowance);
            fairPrice += dueFees;
            // Apply discount based on reward (max 5%)
            // In this case there is no distinction between good or bad liquidation
            fairPrice -= (fairPrice * reward) / (VaultMath.RESOLUTION * 20);
            if (price < fairPrice) {
                revert Liquidator__Below_Fair_Price(price, fairPrice);
            } else {
                strategy.approveAllowance(position);
                IERC20(position.owedToken).safeTransferFrom(liquidatorUser, address(strategy.getVault()), price);
                IERC20(position.heldToken).safeTransferFrom(address(strategy), liquidatorUser, position.allowance);
                // The following is necessary to avoid residual transfers during the repay
                // It means that everything "extra" from principal is fees
                dueFees = price.positiveSub(position.principal);
            }

            strategy.directRepay(
                position.owedToken,
                price,
                position.principal,
                dueFees,
                position.riskFactor,
                liquidatorUser
            );
        } else {
            revert Liquidator__Position_Not_Liquidable(positionId, score);
        }
    }

    /// @notice liquidation method: tops up the collateral of a position and transfers its ownership
    ///         to the liquidator
    /// @param positionId the id of the position to be transferred
    /// @param newCollateral the amount extra collateral transferred to the vault by the liquidator
    /// @param liquidatorUser the address of the user performing the liquidation
    /// @param reward the liquidator's reward ratio
    function _modifyCollateralAndOwner(
        IStrategy strategy,
        uint256 positionId,
        uint256 newCollateral,
        address liquidatorUser,
        uint256 reward
    ) internal {
        IStrategy.Position memory position = strategy.getPosition(positionId);
        (int256 score, uint256 dueFees) = computeLiquidationScore(address(strategy), position);
        if (score > 0) {
            strategy.transferNFT(positionId, liquidatorUser);
            // reduce due fees based on reward (max 50%)
            position.fees += (dueFees * (2 * VaultMath.RESOLUTION - reward)) / (2 * VaultMath.RESOLUTION);
            position.createdAt = block.timestamp;
            bool collateralInOwedToken = position.collateralToken != position.heldToken;
            if (collateralInOwedToken) {
                strategy.directRepay(
                    position.owedToken,
                    newCollateral,
                    newCollateral,
                    0,
                    position.riskFactor,
                    liquidatorUser
                );
            }
            strategy.editPosition(positionId, newCollateral);
            (int256 newScore, ) = computeLiquidationScore(address(strategy), strategy.getPosition(positionId));
            if (newScore > 0) revert Liquidator__Insufficient_Margin_Provided(newScore);
        } else {
            revert Liquidator__Position_Not_Liquidable(positionId, score);
        }
    }

    error Liquidator__Insufficient_Margin_Provided(int256 newScore);
    error Liquidator__Position_Not_Liquidable(uint256 positionId, int256 score);
    error Liquidator__Below_Fair_Price(uint256 price, uint256 fairPrice);
}
