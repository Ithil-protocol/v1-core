// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the Curve contract
/// @author   Curve finance
interface ICurve {
    function add_liquidity(uint256[2] memory amounts, uint256 deadline) external returns (uint256);

    /**
        @notice Withdraw a single coin from the pool
        @param _token_amount Amount of LP tokens to burn in the withdrawal
        @param i Index value of the coin to withdraw
        @param _min_amount Minimum amount of coin to receive
        @return Amount of coin received
    */
    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 _min_amount
    ) external returns (uint256);

    /**
        @notice The current virtual price of the pool LP token
        @dev Useful for calculating profits
        @return LP token virtual price normalized to 1e18
    */
    function get_virtual_price() external view returns (uint256);

    /**
        @notice Calculate addition or reduction in token supply from a deposit or withdrawal
        @dev This calculation accounts for slippage, but not fees.
            Needed to prevent front-running, not for precise calculations!
        @param amounts Amount of each coin being deposited
        @param is_deposit set True for deposits, False for withdrawals
        @return Expected amount of LP tokens received
    */
    function calc_token_amount(uint256[2] memory amounts, bool is_deposit) external view returns (uint256);

    /**
        @notice Perform an exchange between two coins
        @dev Index values can be found via the `coins` public getter method
        @param i Index value for the coin to send
        @param j Index valie of the coin to recieve
        @param dx Amount of `i` being exchanged
        @param min_dy Minimum amount of `j` to receive
        @return Actual amount of `j` received
    */
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}
