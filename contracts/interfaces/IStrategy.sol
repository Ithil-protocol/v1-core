// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IVault } from "../interfaces/IVault.sol";

/// @title    Interface of the parent Strategy contract
/// @author   Ithil
interface IStrategy {
    /// @param spentToken the token we spend to enter the investment
    /// @param obtainedToken the token obtained as result of the investment
    /// @param collateral the amount of tokens to reserve as collateral
    /// @param collateralIsSpentToken if true collateral is in spentToken,
    //                                if false it is in obtainedToken
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
    /// @param allowance the amount of heldToken obtained at the moment the position is opened
    ///                  (without reflections)
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
        uint256 riskFactor;
        uint256 createdAt;
    }

    /// @notice obtain the position at particular id
    /// @param positionId the id of the position
    function getPosition(uint256 positionId) external view returns (Position memory);

    /// @notice obtain the vault
    function vault() external view returns (IVault);

    /// @notice open a position by borrowing from the vault and executing external contract calls
    /// @param order the structure with the order parameters
    function openPosition(Order calldata order) external returns (uint256);

    function openPositionWithPermit(
        Order calldata order,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /// @notice close the position and repays the vault and the user
    /// @param positionId the id of the position to be closed
    /// @param maxOrMin depending on the Position structure, either the maximum amount to spend,
    ///                 or the minimum amount obtained while closing the position
    function closePosition(uint256 positionId, uint256 maxOrMin) external;

    /// @notice function allowing the position's owner to top up the position's collateral
    /// @param positionId the id of the position to be modified
    /// @param topUp the extra collateral to be transferred
    function editPosition(uint256 positionId, uint256 topUp) external;

    /// @notice gives the amount of destination tokens the external protocol
    ///         would produce by spending an amount of source token
    /// @param src the token to give to the external strategy
    /// @param dst the token expected from the external strategy
    /// @param amount the amount of src tokens to be given
    function quote(
        address src,
        address dst,
        uint256 amount
    ) external view returns (uint256, uint256);

    /// @notice computes the risk factor of the token pair, from the individual risk factors
    /// @param token0 first token of the pair
    /// @param token1 second token of the pair
    function computePairRiskFactor(address token0, address token1) external view returns (uint256);

    function deleteAndBurn(uint256 positionId) external;

    function approveAllowance(Position memory position) external;

    function directClosure(Position memory position, uint256 maxOrMin) external returns (uint256);

    function directRepay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        uint256 riskFactor,
        address borrower
    ) external;

    function transferNFT(uint256 positionId, address newOwner) external;

    /// ==== EVENTS ==== ///

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
        uint256 interestRate,
        uint256 fees,
        uint256 createdAt
    );

    /// @notice Emitted when a position is closed
    event PositionWasClosed(uint256 indexed id, uint256 amountIn, uint256 amountOut, uint256 fees);

    /// @notice Emitted when a position is edited
    event PositionWasToppedUp(uint256 indexed id, uint256 topUpAmount);

    /// @notice Emitted when the owner of a position is changed
    event PositionChangedOwner(uint256 indexed id, address oldOwner, address newOwner);

    /// @notice Emitted when a position is liquidated
    event PositionWasLiquidated(uint256 indexed id);

    /// @notice Emitted when the strategy lock toggle is changes
    event StrategyLockWasToggled(bool newLockStatus);

    /// @notice Emitted when the risk factor for a specific token is changed
    event RiskFactorWasUpdated(address indexed token, uint256 newRiskFactor);

    /// ==== ERRORS ==== ///

    error Strategy__Order_Expired(uint256 timestamp, uint256 deadline);
    error Strategy__Source_Eq_Dest(address token);
    error Strategy__Insufficient_Collateral(uint256 collateral);
    error Strategy__Restricted_Access(address owner, address sender);
    error Strategy__Action_Throttled();
    error Strategy__Maximum_Leverage_Exceeded(uint256 interestRate);
    error Strategy__Insufficient_Amount_Out(uint256 amountIn, uint256 minAmountOut);
    error Strategy__Loan_Not_Repaid(uint256 repaid, uint256 debt);
    error Strategy__Only_Liquidator(address sender, address liquidator);
    error Strategy__Position_Not_Liquidable(uint256 id, int256 score);
    error Strategy__Margin_Below_Minimum(uint256 marginProvider, uint256 minimumMargin);
    error Strategy__Insufficient_Margin_Provided(int256 newScore);
    error Strategy__Not_Enough_Liquidity(uint256 balance, uint256 amount);
    error Strategy__Unsupported_Token(address token0, address token1);
    error Strategy__Too_High_Risk(uint256 riskFactor);
    error Strategy__Locked();
    error Strategy__Only_Guardian();
    error Strategy__Incorrect_Obtained_Token();
}
