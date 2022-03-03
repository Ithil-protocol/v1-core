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

    function liquidateSingle(address _strategy, uint256 positionId) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        strategy.forcefullyClose(positionId);
    }

    function marginCall(
        address _strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        strategy.modifyCollateralAndOwner(positionId, extraMargin, msg.sender);
    }

    function purchaseAssets(
        address _strategy,
        uint256 positionId,
        uint256 price
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        strategy.forcefullyDelete(msg.sender, positionId, price);
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
