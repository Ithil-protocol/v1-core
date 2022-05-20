// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { IExchange } from "../interfaces/IExchange.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/// @title    Exchange proxy contract
/// @author   Ithil
/// @notice   Used to swap treasury tokens for another one
contract UniV3 is IExchange {
    ISwapRouter private immutable router;

    constructor(address _router) {
        router = ISwapRouter(_router);
    }

    function swap(
        uint256 amount,
        uint256 minAmountIn,
        bytes calldata data
    ) external override returns (uint256 amountOut) {
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: data,
            recipient: msg.sender,
            deadline: 60,
            amountIn: amount,
            amountOutMinimum: minAmountIn
        });

        amountOut = router.exactInput(params);
    }
}
