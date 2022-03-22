// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

/// @title    AbstractStrategy contract
/// @author   Ithil
/// @notice   Abstract contract which represent the core of the strategies
abstract contract AbstractStrategy is IStrategy, Ownable {
    IVault public immutable vault;
    mapping(uint256 => Position) public positions;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function name() external pure virtual returns (string memory);

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
}
