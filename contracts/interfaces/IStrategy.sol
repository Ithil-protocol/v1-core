// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

/// @title    Interface of the parent Strategy contract
/// @author   Ithil
interface IStrategy {
    /// @param spentToken the token we spend to enter the investment
    /// @param obtainedToken the token obtained as result of the investment
    /// @param collateral the amount of tokens to reserve as collateral
    /// @param collateralIsSpentToken if true collateral is in spentToken, else it is in obtainedToken
    /// @param minObtained the min amount of obtainedToken to obtain
    /// @param maxSpent the max amount of spentToken to spend
    /// @param deadline this order must be executed before deadline
    struct Order {
        address spentToken;
        address obtainedToken;
        uint256 collateral;
        bool collateralIsSpentToken;
        uint256 minObtained;
        uint256 maxSpent;
        uint256 deadline;
    }

    /// @param owner the account who opened the position
    /// @param owedToken the token which must be repayed to the vault
    /// @param heldToken the token held in the strategy as investment effect
    /// @param collateralToken the token used as collateral
    /// @param collateral the amount of tokens used as collateral
    /// @param principal the amount of borrowed tokens on which the interests are calculated
    /// @param allowance the amount of heldToken obtained at the moment the position is opened (without reflections)
    /// @param interestRate the interest rate paid on the loan
    /// @param fees the fees generated by the position so far
    /// @param createdAt the date and time in unix epoch when the position was opened
    struct Position {
        address owedToken;
        address heldToken;
        address collateralToken;
        uint256 collateral;
        uint256 principal;
        uint256 allowance;
        uint256 interestRate;
        uint256 fees;
        uint256 createdAt;
    }

    /// @notice Emitted when a new position has been opened
    event PositionWasOpened(
        uint256 indexed id,
        address indexed owner,
        address owedToken,
        address heldToken,
        address collateralToken,
        uint256 collateral,
        uint256 principal,
        uint256 allowance,
        uint256 interestRtae,
        uint256 createdAt
    );

    function computePairRiskFactor(address token0, address token1) external view returns (uint256);

    function quote(
        address src,
        address dst,
        uint256 amount
    ) external view returns (uint256, uint256);

    function forcefullyClose(
        uint256 _id,
        address liquidator,
        uint256 penalty
    ) external;

    function transferAllowance(
        uint256 positionId,
        uint256 price,
        address purchaser,
        uint256 penalty
    ) external;

    function modifyCollateralAndOwner(
        uint256 _id,
        uint256 newCollateral,
        address newOwner,
        uint256 penalty
    ) external;

    function getPosition(uint256 positionId) external view returns (Position memory);

    function vaultAddress() external view returns (address);

    /// @notice Emitted when a position is closed
    event PositionWasClosed(uint256 indexed id);

    /// @notice Emitted when a position is liquidated
    event PositionWasLiquidated(uint256 indexed id);

    /// @notice Emitted when the strategy lock toggle is changes
    event StrategyLockWasToggled(bool newLockStatus);

    error Strategy__Invalid_Position(uint256 id, address strategy);
    error Strategy__Order_Expired(uint256 timestamp, uint256 deadline);
    error Strategy__Source_Eq_Dest(address token);
    error Strategy__Insufficient_Collateral(uint256 collateral);
    error Strategy__Restricted_Access(address owner, address sender);
    error Strategy__Throttled(uint256 createdAt, uint256 timestamp);
    error Strategy__Maximum_Leverage_Exceeded(uint256 interestRate);
    error Strategy__Insufficient_Amount_Out(uint256 amountIn, uint256 minAmountOut);
    error Strategy__Loan_Not_Repaid(uint256 repaid, uint256 debt);
    error Strategy__Only_Liquidator(address sender, address liquidator);
    error Strategy__Nonpositive_Score(int256 score);
    error Strategy__Margin_Below_Minimum(uint256 marginProvider, uint256 minimumMargin);
    error Strategy__Insufficient_Margin_Provided(int256 newScore);
    error Strategy__Locked();
    error Strategy__Only_Guardian();
    error Strategy__Incorrect_Obtained_Token();
}
