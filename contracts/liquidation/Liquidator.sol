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
}
