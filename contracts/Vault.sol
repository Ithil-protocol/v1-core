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
import { WrappedToken } from "./WrappedToken.sol";

/// @title    Vault contract
/// @author   Ithil
/// @notice   Stores staked funds, issues loans and handles repayments to strategies
contract Vault is IVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
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

    function toggleOusdRebase(bool enabled) external onlyOwner {
        if (enabled) {
            (bool success, ) = address(0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86).call(
                abi.encodeWithSignature("rebaseOptIn()")
            );
            assert(success);
        } else {
            (bool success, ) = address(0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86).call(
                abi.encodeWithSignature("rebaseOptOut()")
            );
            assert(success);
        }
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
            VaultMath.calculateLockedProfit(vaultState.currentProfits, block.timestamp, vaultState.latestRepay);
    }

    function claimable(address token) external view override returns (uint256) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);

        return VaultMath.nativesPerShares(wToken.balanceOf(msg.sender), wToken.totalSupply(), balance(token));
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

        emit TokenWasWhitelisted(token, baseFee, fixedFee, minimumMargin);
    }

    function editMinimumMargin(address token, uint256 minimumMargin) external override onlyOwner {
        checkWhitelisted(token);

        vaults[token].minimumMargin = minimumMargin;

        emit MinimumMarginWasUpdated(token, minimumMargin);
    }

    function stake(address token, uint256 amount) external override unlocked(token) isValidAmount(amount) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);

        uint256 toMint = VaultMath.sharesPerNatives(amount, wToken.totalSupply(), balance(token));
        if (toMint == 0) revert Vault__Null_Amount();
        // Transfer must be after calculation because alters balance
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        wToken.mint(msg.sender, toMint);

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
        uint256 toMint = VaultMath.sharesPerNatives(amount, wToken.totalSupply(), balance(weth));
        if (toMint == 0) revert Vault__Null_Amount();

        IWETH(weth).deposit{ value: amount }();
        wToken.mint(msg.sender, toMint);

        emit Deposit(msg.sender, weth, amount, toMint);
    }

    function unstake(address token, uint256 amount) external override isValidAmount(amount) {
        checkWhitelisted(token);

        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);
        uint256 totalSupply = wToken.totalSupply();
        uint256 totalBalance = balance(token);
        uint256 toBurn = VaultMath.sharesPerNatives(amount, totalSupply, totalBalance);
        uint256 toWithdraw = VaultMath.nativesPerShares(toBurn, totalSupply, totalBalance);
        if (toBurn == 0 || toWithdraw == 0) revert Vault__Null_Amount();

        wToken.burn(msg.sender, toBurn);
        IERC20(token).safeTransfer(msg.sender, toWithdraw);

        emit Withdrawal(msg.sender, token, toWithdraw, toBurn);
    }

    function unstakeETH(uint256 amount) external override isValidAmount(amount) {
        checkWhitelisted(weth);

        IWrappedToken wToken = IWrappedToken(vaults[weth].wrappedToken);
        uint256 totalSupply = wToken.totalSupply();
        uint256 totalBalance = balance(weth);
        uint256 toBurn = VaultMath.sharesPerNatives(amount, totalSupply, totalBalance);
        uint256 toWithdraw = VaultMath.nativesPerShares(toBurn, totalSupply, totalBalance);

        IWETH(weth).withdraw(toWithdraw);

        // slither-disable-next-line reentrancy-events,arbitrary-send
        (bool success, bytes memory data) = payable(msg.sender).call{ value: toWithdraw }("");
        if (!success) revert Vault__ETH_Unstake_Failed(data);

        emit Withdrawal(msg.sender, weth, toWithdraw, toBurn);
    }

    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    ) external override unlocked(token) onlyStrategy returns (uint256, uint256) {
        checkWhitelisted(token);

        VaultState.VaultData storage vaultData = vaults[token];
        uint256 baseInterestRate = 0;
        uint256 fees = vaultData.fixedFee;
        if (amount > 0) {
            uint256 freeLiquidity = vaultData.takeLoan(IERC20(token), amount, riskFactor);

            baseInterestRate = VaultMath.computeInterestRateNoLeverage(
                vaultData.netLoans - amount,
                freeLiquidity,
                vaultData.insuranceReserveBalance,
                riskFactor,
                vaultData.baseFee
            );

            emit LoanTaken(borrower, token, amount, baseInterestRate);
        }

        return (baseInterestRate, fees);
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
