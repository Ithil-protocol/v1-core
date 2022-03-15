// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

interface ICurve {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function remove_liquidity(uint256 lpAmount, uint256[2] memory minAmounts) external;

    function get_virtual_price() external view returns (uint256);

    function calc_token_amount(uint256[2] memory, bool) external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}
