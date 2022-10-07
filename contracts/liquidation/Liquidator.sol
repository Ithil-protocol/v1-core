// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { IStaker } from "../interfaces/IStaker.sol";

/// @title    Liquidator contract
/// @author   Ithil
/// @notice   Base liquidation contract, can forcefully close base strategy's positions
contract Liquidator is Ownable {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    IStaker public staker;

    error Liquidator__Insufficient_Margin_Provided(int256 newScore);
    error Liquidator__Position_Not_Liquidable(uint256 positionId, int256 score);
    error Liquidator__Below_Fair_Price(uint256 price, uint256 fairPrice);

    constructor(address _staker) {
        staker = IStaker(_staker);
    }

    function setToken(address _staker) external onlyOwner {
        staker = IStaker(_staker);
    }

    function liquidateSingle(IStrategy strategy, uint256 positionId) external {
        uint256 reward = staker.rewardPercentage();
        _forcefullyClose(strategy, positionId, msg.sender, reward);
    }

    function marginCall(
        IStrategy strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        uint256 reward = staker.rewardPercentage();
        _modifyCollateralAndOwner(strategy, positionId, extraMargin, msg.sender, reward);
    }

    function purchaseAssets(
        IStrategy strategy,
        uint256 positionId,
        uint256 price
    ) external {
        uint256 reward = staker.rewardPercentage();
        _transferAllowance(strategy, positionId, price, msg.sender, reward);
    }

    // Liquidator
    function computeLiquidationScore(address _strategy, uint256 _positionId) public view returns (int256, uint256) {
        IStrategy strategy = IStrategy(_strategy);
        IStrategy.Position memory position = strategy.getPosition(_positionId);
        (int256 score, uint256 dueFees, , ) = _computeLiquidationScore(strategy, position);
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

        (int256 score, uint256 dueFees, , ) = _computeLiquidationScore(strategy, position);
        if (score > 0) {
            strategy.deleteAndBurn(positionId);
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;

            uint256 maxOrMin = collateralInHeldTokens ? position.allowance : 0;

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
        (int256 score, uint256 dueFees, uint256 fairPrice, ) = _computeLiquidationScore(strategy, position);
        if (score > 0) {
            strategy.deleteAndBurn(positionId);
            // This is the market price of the position's allowance in owedTokens
            // No need to distinguish between collateral in held tokens or not
            fairPrice += dueFees;
            // Apply discount based on reward (max 5%)
            // In this case there is no distinction between good or bad liquidation
            fairPrice -= (fairPrice * reward) / (VaultMath.RESOLUTION * 20);
            if (price < fairPrice) {
                revert Liquidator__Below_Fair_Price(price, fairPrice);
            } else {
                strategy.approveAllowance(position);

                // slither-disable-next-line arbitrary-send-erc20
                IERC20(position.owedToken).safeTransferFrom(liquidatorUser, address(strategy.vault()), price);
                // slither-disable-next-line arbitrary-send-erc20
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
        (int256 score, uint256 dueFees, , ) = _computeLiquidationScore(strategy, position);
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
            (int256 newScore, ) = computeLiquidationScore(address(strategy), positionId);
            if (newScore > 0) revert Liquidator__Insufficient_Margin_Provided(newScore);
        } else {
            revert Liquidator__Position_Not_Liquidable(positionId, score);
        }
    }

    function _computeLiquidationScore(IStrategy strategy, IStrategy.Position memory position)
        internal
        view
        returns (
            int256,
            uint256,
            uint256,
            uint256
        )
    {
        bool collateralInOwedToken = position.collateralToken != position.heldToken;
        uint256 expectedTokensOwed = 0;
        uint256 expectedTokensHeld = 0;
        int256 profitAndLoss = 0;

        uint256 dueFees = position.fees +
            (position.interestRate * (block.timestamp - position.createdAt) * position.principal) /
            (uint32(VaultMath.TIME_FEE_PERIOD) * VaultMath.RESOLUTION);

        if (collateralInOwedToken) {
            (expectedTokensOwed, ) = strategy.quote(position.heldToken, position.owedToken, position.allowance);
            profitAndLoss = SafeCast.toInt256(expectedTokensOwed) - SafeCast.toInt256(position.principal + dueFees);
        } else {
            (expectedTokensHeld, ) = strategy.quote(
                position.owedToken,
                position.heldToken,
                position.principal + dueFees
            );
            profitAndLoss = SafeCast.toInt256(position.allowance) - SafeCast.toInt256(expectedTokensHeld);
        }

        int256 score = SafeCast.toInt256(position.collateral * position.riskFactor) -
            profitAndLoss *
            int24(VaultMath.RESOLUTION);

        return (score, dueFees, expectedTokensOwed, expectedTokensHeld);
    }
}
