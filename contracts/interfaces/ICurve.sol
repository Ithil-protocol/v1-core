// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the Curve contract
/// @author   Curve finance
interface ICurve {
    function token() external view returns (address);

    function lp_token() external view returns (address);

    function coins(uint256 i) external view returns (address);

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

    function calc_token_amount(uint256[3] memory amounts, bool is_deposit) external view returns (uint256);

    function calc_token_amount(uint256[2] memory amounts) external view returns (uint256);

    function calc_token_amount(uint256[3] memory amounts) external view returns (uint256);
}

/// @dev Pool implementation with aToken-style lending (i.e., interest accrues as balance increases)
interface ICurveA is ICurve {
    /**
        @notice Deposit coins into the pool
        @param _amounts List of amounts of coins to deposit
        @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
        @param _use_underlying If True, deposit underlying assets instead of aTokens
        @return Amount of LP tokens received by depositing
    */
    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount,
        bool _use_underlying
    ) external returns (uint256);

    function add_liquidity(
        uint256[3] memory _amounts,
        uint256 _min_mint_amount,
        bool _use_underlying
    ) external returns (uint256);

    /**
        @notice Withdraw a single coin from the pool
        @param _token_amount Amount of LP tokens to burn in the withdrawal
        @param i Index value of the coin to withdraw
        @param _min_amount Minimum amount of coin to receive
        @param _use_underlying If True, withdraw underlying assets instead of aTokens
        @return Amount of coin received
    */
    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 _min_amount,
        bool _use_underlying
    ) external returns (uint256);
}

/// @dev Pool implementation with yearn-style lending (i.e., interest accrues as rate increases)
interface ICurveY is ICurve {
    /**
        @notice Deposit coins into the pool
        @param _amounts List of amounts of coins to deposit
        @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
        @return Amount of LP tokens received by depositing
    */
    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

    function add_liquidity(uint256[3] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

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
}
