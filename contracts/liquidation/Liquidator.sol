// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    Liquidator contract
/// @author   Ithil
/// @notice   Base liquidation contract, can forcefully close base strategy's positions
contract Liquidator is Ownable {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;

    error Insufficient_Margin_Call(uint256);
    error Insufficient_Price(uint256);

    function computeLiquidationScore(address _strategy, IStrategy.Position memory position)
        public
        view
        returns (int256 score, uint256 dueFees)
    {
        IStrategy strategy = IStrategy(_strategy);
        bool collateralInOwedToken = position.collateralToken != position.heldToken;
        uint256 pairRiskFactor = strategy.computePairRiskFactor(position.heldToken, position.owedToken);
        uint256 expectedTokens;
        int256 profitAndLoss;

        dueFees =
            position.fees +
            (position.interestRate * (block.timestamp - position.createdAt) * position.principal) /
            (uint32(VaultMath.TIME_FEE_PERIOD) * VaultMath.RESOLUTION);

        if (collateralInOwedToken) {
            (expectedTokens, ) = strategy.quote(position.heldToken, position.owedToken, position.allowance);
            profitAndLoss = int256(expectedTokens) - int256(position.principal + dueFees);
        } else {
            (expectedTokens, ) = strategy.quote(position.heldToken, position.owedToken, position.principal + dueFees);
            profitAndLoss = int256(position.allowance) - int256(expectedTokens);
        }

        score = int256(position.collateral * pairRiskFactor) - profitAndLoss * int24(VaultMath.RESOLUTION);
    }

    function liquidateSingle(address _strategy, uint256 positionId) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        IStrategy.Position memory position = strategy.getPosition(positionId);
        uint256 totalAllowances = strategy.totalAllowance(position.heldToken);

        if (totalAllowances > 0) {
            position.allowance *= IERC20(position.heldToken).balanceOf(_strategy);
            position.allowance /= (totalAllowances + position.allowance);
        }

        (int256 score, uint256 dueFees) = computeLiquidationScore(_strategy, position);
        if (score > 0) {
            strategy.forcefullyDelete(positionId);
            uint256 expectedCost = 0;
            bool collateralInHeldTokens = position.collateralToken != position.owedToken;
            if (collateralInHeldTokens)
                (expectedCost, ) = strategy.quote(
                    position.owedToken,
                    position.heldToken,
                    position.principal + position.fees
                );
            if (position.allowance > 0) strategy.forcefullyClose(position, expectedCost);
        }
    }

    function marginCall(
        address _strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        IStrategy.Position memory position = strategy.getPosition(positionId);
        (int256 score, ) = computeLiquidationScore(_strategy, position);
        if (score > 0) {
            (, uint256 received) = IERC20(position.collateralToken).transferTokens(msg.sender, _strategy, extraMargin);
            strategy.modifyCollateralAndOwner(positionId, received, msg.sender);
            (int256 newScore, ) = computeLiquidationScore(_strategy, strategy.getPosition(positionId));
            if (newScore > 0) revert Insufficient_Margin_Call(extraMargin);
        }
    }

    function purchaseAssets(
        address _strategy,
        uint256 positionId,
        uint256 price
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        IStrategy.Position memory position = strategy.getPosition(positionId);
        (int256 score, ) = computeLiquidationScore(_strategy, position);
        address vault = strategy.vaultAddress();

        //todo: this contract is not a strategy, thus it cannot repay the vault (modify net loans).
        //todo: put some specific strategy function to make this possible
        if (score > 0) {
            (, uint256 received) = IERC20(position.owedToken).transferTokens(msg.sender, vault, price);
            //todo: calculate fees!
            if (received < position.principal + position.fees) revert Insufficient_Price(price);
            else IERC20(position.heldToken).transferTokens(_strategy, msg.sender, position.allowance);
        }
    }

    // function liquidate(address _strategy, uint256[] memory positionIds) external {
    //     IStrategy strategy = IStrategy(_strategy);
    //     //todo: add checks on liquidator
    //     IStrategy.Position memory modelPosition = strategy.positions[positionIds[0]];
    //     modelPosition.allowance = 0;
    //     modelPosition.principal = 0;
    //     modelPosition.fees = 0;
    //     modelPosition.interestRate = 0;
    //     modelPosition.owner = msg.sender;
    //     for (uint256 i = 0; i < positionIds.length; i++) {
    //         IStrategy.Position memory position = strategy.positions[positionIds[i]];

    //         if (position.heldToken != modelPosition.heldToken || position.owedToken != modelPosition.owedToken)
    //             continue;

    //         if (strategy.totalAllowances[position.heldToken] > 0) {
    //             uint256 nominalAllowance = position.allowance;
    //             totalAllowances[position.heldToken] -= nominalAllowance;
    //             position.allowance *= IERC20(position.heldToken).balanceOf(address(this));
    //             position.allowance /= (totalAllowances[position.heldToken] + nominalAllowance);
    //         }

    //         (int256 score, uint256 dueFees) = computeLiquidationScore(position);
    //         if (score > 0) {
    //             baseStrategy.forcefullyDelete(positionIds[i]);
    //             modelPosition.allowance += position.allowance;
    //             modelPosition.principal += position.principal;
    //             modelPosition.fees += dueFees;
    //         }
    //     }

    //     uint256 expectedCost = 0;
    //     bool collateralInHeldTokens = modelPosition.collateralToken != modelPosition.owedToken;

    //     if (collateralInHeldTokens)
    //         (expectedCost, ) = _quote(
    //             modelPosition.owedToken,
    //             modelPosition.heldToken,
    //             modelPosition.principal + modelPosition.fees
    //         );
    //     if (modelPosition.allowance > 0) _closePosition(modelPosition, expectedCost);
    // }
}
