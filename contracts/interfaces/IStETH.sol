// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStETH is IERC20 {
    // Send funds to the pool with optional _referral parameter
    function submit(address _referral) external payable returns (uint256);

    // Fee in basis points. 10000 BP corresponding to 100%
    function getFee() external view returns (uint16);

    // Returns the amount of shares owned by _account
    function sharesOf(address _account) external view returns (uint256);
}
