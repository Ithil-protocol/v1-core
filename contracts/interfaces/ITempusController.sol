// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { ITempusPool } from "./ITempusPool.sol";

interface ITempusController {
    function depositBacking(
        ITempusPool tempusPool,
        uint256 backingTokenAmount,
        address recipient
    ) external payable returns (uint256);

    function redeemToBacking(
        ITempusPool tempusPool,
        uint256 principalAmount,
        uint256 yieldAmount,
        address recipient
    ) external;
}
