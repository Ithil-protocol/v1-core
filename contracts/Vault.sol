// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IWrappedToken } from "./interfaces/IWrappedToken.sol";
import { IWETH } from "./interfaces/external/IWETH.sol";
import { VaultMath } from "./libraries/VaultMath.sol";
import { VaultState } from "./libraries/VaultState.sol";
import { GeneralMath } from "./libraries/GeneralMath.sol";
import { WrappedTokenHelper } from "./libraries/WrappedTokenHelper.sol";
import { WrappedToken } from "./WrappedToken.sol";

/// @title    Vault contract
/// @author   Ithil
/// @notice   Stores staked funds, issues loans and handles repayments to strategies
contract Vault is IVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using WrappedTokenHelper for IWrappedToken;
    using VaultMath for uint256;
    using GeneralMath for uint256;
    using GeneralMath for VaultState.VaultData;
    using VaultState for VaultState.VaultData;

    address public immutable override weth;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public guardian;

    mapping(address => VaultState.VaultData) public vaults;
    mapping(address => bool) public strategies;
    mapping(address => mapping(address => uint256)) public boosters;

    constructor(address _weth) {
        weth = _weth;
    }

    modifier isValidAmount(uint256 amount) {
        if (amount == 0) revert Vault__Null_Amount();
        _;
    }

    modifier unlocked(address token) {
        if (vaults[token].locked) revert Vault__Locked(token);
        _;
    }

    modifier onlyStrategy() {
        if (!strategies[msg.sender]) revert Vault__Restricted_Access();
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian && msg.sender != owner()) revert Vault__Only_Guardian();
        _;
    }

    // only accept ETH from the WETH contract
    receive() external payable {
        if (msg.sender != weth) revert Vault__ETH_Callback_Failed();
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
    }

    function checkWhitelisted(address token) public view override {
        if (!vaults[token].supported && token != ETH) revert Vault__Unsupported_Token(token);
    }

    function getMinimumMargin(address token) external view returns (uint256) {
        return vaults[token].minimumMargin;
    }

    function balance(address token) public view override returns (uint256) {
        VaultState.VaultData memory vaultState = vaults[token];
        return
            IERC20(token).balanceOf(address(this)) +
            vaultState.netLoans -
            vaultState.insuranceReserveBalance -
            vaultState.boostedAmount -
            VaultState.calculateLockedProfit(vaultState);
    }

    function claimable(address token) external view override returns (uint256) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);

        return VaultMath.maximumWithdrawal(wToken.balanceOf(msg.sender), wToken.totalSupply(), balance(token));
    }

    function toggleLock(bool locked, address token) external override onlyGuardian {
        vaults[token].locked = locked;

        emit VaultLockWasToggled(locked, token);
    }

    function addStrategy(address strategy) external override onlyOwner {
        strategies[strategy] = true;

        emit StrategyWasAdded(strategy);
    }

    function removeStrategy(address strategy) external override onlyOwner {
        delete strategies[strategy];

        emit StrategyWasRemoved(strategy);
    }

    function whitelistToken(
        address token,
        uint256 baseFee,
        uint256 fixedFee,
        uint256 minimumMargin
    ) public override onlyOwner {
        if (vaults[token].supported) revert Vault__Token_Already_Supported(token);

        // deploys a wrapped token contract
        vaults[token].wrappedToken = address(new WrappedToken(token));
        vaults[token].supported = true;
        vaults[token].creationTime = block.timestamp;
        vaults[token].baseFee = baseFee;
        vaults[token].fixedFee = fixedFee;
        vaults[token].minimumMargin = minimumMargin;

        emit TokenWasWhitelisted(token);
    }

    function whitelistTokenAndExec(
        address token,
        uint256 baseFee,
        uint256 fixedFee,
        uint256 minimumMargin,
        bytes calldata data
    ) external override onlyOwner {
        whitelistToken(token, baseFee, fixedFee, minimumMargin);

        // slither-disable-next-line controlled-delegatecall
        (bool success, ) = token.delegatecall(data);
        assert(success);
    }

    function editMinimumMargin(address token, uint256 minimumMargin) external override onlyOwner {
        checkWhitelisted(token);

        vaults[token].minimumMargin = minimumMargin;

        emit MinimumMarginWasUpdated(token, minimumMargin);
    }

    function stake(address token, uint256 amount) external override unlocked(token) isValidAmount(amount) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);
        uint256 totalWealth = balance(token);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 toMint = wToken.mintWrapped(amount, msg.sender, totalWealth);

        emit Deposit(msg.sender, token, amount, toMint);
    }

    function boost(address token, uint256 amount) external override unlocked(token) isValidAmount(amount) {
        checkWhitelisted(token);

        vaults[token].boostedAmount += amount;
        boosters[msg.sender][token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Boosted(msg.sender, token, amount);
    }

    function unboost(address token, uint256 amount) external override isValidAmount(amount) {
        uint256 boosted = boosters[msg.sender][token];
        if (boosted < amount) revert Vault__Insufficient_Funds_Available(token, amount, boosted);
        vaults[token].boostedAmount -= amount;
        boosters[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Unboosted(msg.sender, token, amount);
    }

    function stakeETH(uint256 amount) external payable override unlocked(weth) isValidAmount(amount) {
        checkWhitelisted(weth);

        if (msg.value != amount) revert Vault__Insufficient_ETH(msg.value, amount);

        IWrappedToken wToken = IWrappedToken(vaults[weth].wrappedToken);
        uint256 totalWealth = balance(weth);

        IWETH(weth).deposit{ value: amount }();

        uint256 toMint = wToken.mintWrapped(amount, msg.sender, totalWealth);

        emit Deposit(msg.sender, weth, amount, toMint);
    }

    function unstake(address token, uint256 amount) external override isValidAmount(amount) {
        checkWhitelisted(token);

        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);
        uint256 maxWithdrawal = VaultMath.maximumWithdrawal(
            wToken.balanceOf(msg.sender),
            wToken.totalSupply(),
            balance(token)
        );
        if (maxWithdrawal < amount) revert Vault__Max_Withdrawal(msg.sender, token, amount, maxWithdrawal);
        uint256 toBurn = wToken.burnWrapped(amount, balance(token), msg.sender);

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount, toBurn);
    }

    function unstakeETH(uint256 amount) external override isValidAmount(amount) {
        checkWhitelisted(weth);

        IWrappedToken wToken = IWrappedToken(vaults[weth].wrappedToken);
        uint256 toBurn = wToken.burnWrapped(amount, balance(weth), msg.sender);
        IWETH(weth).withdraw(amount);

        // slither-disable-next-line reentrancy-events,arbitrary-send
        (bool success, bytes memory data) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert Vault__ETH_Unstake_Failed(data);

        emit Withdrawal(msg.sender, weth, amount, toBurn);
    }

    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    ) external override unlocked(token) onlyStrategy returns (uint256 baseInterestRate, uint256 fees) {
        checkWhitelisted(token);

        VaultState.VaultData storage vaultData = vaults[token];
        if (amount > 0) {
            uint256 freeLiquidity = vaultData.takeLoan(IERC20(token), amount, riskFactor);

            baseInterestRate = VaultMath.computeInterestRateNoLeverage(
                vaultData.netLoans - amount,
                freeLiquidity,
                vaultData.insuranceReserveBalance,
                riskFactor,
                vaultData.baseFee
            );
        }
        fees = VaultMath.computeFees(amount, vaultData.fixedFee);

        emit LoanTaken(borrower, token, amount, baseInterestRate);
    }

    function repay(
        address token,
        uint256 amount,
        uint256 debt,
        uint256 fees,
        uint256 riskFactor,
        address borrower
    ) external override onlyStrategy {
        checkWhitelisted(token);

        VaultState.VaultData storage vaultData = vaults[token];

        vaultData.repayLoan(IERC20(token), borrower, debt, fees, amount, riskFactor);

        emit LoanRepaid(borrower, token, amount);
    }
}
