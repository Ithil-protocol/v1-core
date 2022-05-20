// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

interface IExchange {
    function swap(
        uint256 amount,
        uint256 minAmountIn,
        bytes calldata data
    ) external returns (uint256 amountOut);
}
