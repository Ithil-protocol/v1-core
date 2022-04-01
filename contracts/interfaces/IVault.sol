// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { VaultState } from "../libraries/VaultState.sol";

/// @title    Interface of Vault contract
/// @author   Ithil
interface IVault {
    /// ==== STAKING ==== ///

    function state(address token) external view returns (VaultState.VaultData memory);

    /// @notice Gets the amount of tokens a user can get back when unstaking
    /// @param token the token to check the claimable amount against
    function claimable(address token) external view returns (uint256);

    /// @notice Add tokens to the vault, and updates internal status to register updated claiming powers
    /// @param token the token to deposit
    /// @param amount the amount of native tokens deposited
    function stake(address token, uint256 amount) external;

    /// @notice Remove tokens from the vault, and updates internal status to register updated claiming powers
    /// @param token the token to deposit
    /// @param amount the amount of native tokens withdrawn
    function unstake(address token, uint256 amount) external;

    /// ==== ADMIN ==== ///

    /// @notice Adds a new strategy address to the list
    /// @param strategy the strategy to add
    function addStrategy(address strategy) external;

    /// @notice Removes a strategy address from the list
    /// @param strategy the strategy to remove
    function removeStrategy(address strategy) external;

    /// @notice Locks/unlocks a token
    /// @param status the status to be achieved
    /// @param token the token to apply it to
    function toggleLock(bool status, address token) external;

    /// @notice adds a new supported token
    /// @param token the token to whitelist
    function whitelistToken(
        address token,
        uint256 baseFee,
        uint256 fixedFee
    ) external;

    /// @notice adds a new supported token and executes an arbitrary function on it
    function whitelistTokenAndExec(
        address token,
        uint256 baseFee,
        uint256 fixedFee,
        bytes calldata data
    ) external;

    /// ==== LENDING ==== ///

    /// @notice shows the available balance to borrow in the vault
    /// @param token the token to check
    /// @return available balance
    function balance(address token) external view returns (uint256);

    /// @notice updates state to borrow tokens from the vault
    /// @param token the token to borrow
    /// @param amount the total amount to borrow
    /// @param riskFactor the riskiness of this loan
    /// @param borrower the ultimate requester of the loan
    /// @return interestRate the interest rate calculated for the loan
    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    ) external returns (uint256 interestRate, uint256 fees);

    /// @notice repays a loan
    /// @param token the token of the loan
    /// @param amount the total amount transfered during the repayment
    /// @param debt the debt of the loan
    /// @param borrower the owner of the loan
    function repay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        address borrower
    ) external;

    /// ==== EVENTS ==== ///

    /// @notice Emitted when a deposit has been performed
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 claimingPower);

    /// @notice Emitted when a withdrawal has been performed
    event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 claimingPower);

    /// @notice Emitted when the vault has been locked or unlocked
    event VaultLockWasToggled(bool status, address indexed token);

    /// @notice Emitted when a new strategy is added to the vault
    event StrategyWasAdded(address strategy);

    /// @notice Emitted when an existing strategy is removed from the vault
    event StrategyWasRemoved(address strategy);

    /// @notice Emitted when a token is whitelisted
    event TokenWasWhitelisted(address indexed token);

    /// @notice Emitted when a loan is opened and issued
    event LoanTaken(address indexed borrower, address indexed token, uint256 amount);

    /// @notice Emitted when a loan gets repaid and closed
    event LoanRepaid(address indexed borrower, address indexed token, uint256 amount);

    /// ==== ERRORS ==== ///

    error Vault__Unsupported_Token(address);
    error Vault__Token_Already_Supported(address);
    error Vault__ETH_Transfer_Failed();
    error Vault__Restricted_Access();
    error Vault__Insufficient_Funds_Available(address, uint256);
    error Vault__Insufficient_Margin(address, address);
    error Vault__Locked(address);
    error Vault__Max_Withdrawal(address, address);
    error Vault__Null_Amount();
}
