// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { AbstractStrategy } from "./AbstractStrategy.sol";

/// @title    Liquidable contract
/// @author   Ithil
/// @notice   Liquidable contract to collect liquidator data and functions

abstract contract Liquidable is AbstractStrategy {
    address public immutable liquidator;

    constructor(address _liquidator, address _vault) AbstractStrategy(_vault) {
        liquidator = _liquidator;
    }

    modifier onlyLiquidator() {
        if (msg.sender != liquidator) revert Only_Liquidator(msg.sender, liquidator);
        _;
    }

    function forcefullyClose(Position memory position, uint256 expectedCost) external override onlyLiquidator {
        _closePosition(position, expectedCost);
    }

    function forcefullyDelete(uint256 _id) external override onlyLiquidator {
        Position memory position = positions[_id];
        delete positions[_id];
        if (totalAllowances[position.heldToken] > 0) totalAllowances[position.heldToken] -= position.allowance;
        emit PositionWasLiquidated(_id);
    }

    function modifyCollateralAndOwner(
        uint256 _id,
        uint256 newCollateral,
        address newOwner
    ) external override onlyLiquidator {
        positions[_id].collateral += newCollateral;
        positions[_id].owner = newOwner;
    }
}
