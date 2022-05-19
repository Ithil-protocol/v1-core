// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IWrappedToken } from "./interfaces/IWrappedToken.sol";
import { VaultMath } from "./libraries/VaultMath.sol";
import { VaultState } from "./libraries/VaultState.sol";
import { GeneralMath } from "./libraries/GeneralMath.sol";
import { WrappedToken } from "./WrappedToken.sol";
import { WToken } from "./libraries/WToken.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

/// @title    Vault contract
/// @author   Ithil
/// @notice   Stores staked funds, issues loans and handles repayments to strategies
contract Vault is IVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;
    using WToken for IWrappedToken;
    // using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;
    using VaultMath for uint256;
    using GeneralMath for uint256;
    using GeneralMath for VaultState.VaultData;
    using VaultState for VaultState.VaultData;

    address public immutable override weth;
    address internal immutable treasury;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => VaultState.VaultData) public vaults;
    mapping(address => bool) public strategies;

    constructor(address _weth, address _treasury) {
        weth = _weth;
        treasury = _treasury;
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
        if (!strategies[msg.sender]) revert Vault__Restricted_Access(msg.sender);
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert Vault__Restricted_Access(msg.sender);
        _;
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        if (msg.sender != weth) revert Vault__ETH_Transfer_Failed(msg.sender, weth);
    }

    function checkWhitelisted(address token) public view override {
        if (!vaults[token].supported && token != ETH) revert Vault__Unsupported_Token(token);
    }

    function balance(address token) public view override returns (uint256) {
        return
            IERC20(token).balanceOf(address(this)) +
            vaults[token].netLoans -
            vaults[token].insuranceReserveBalance -
            vaults[token].treasuryLiquidity;
    }

    function claimable(address token) external view override returns (uint256) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);

        return VaultMath.maximumWithdrawal(wToken.balanceOf(msg.sender), wToken.totalSupply(), balance(token));
    }

    function toggleLock(bool locked, address token) external override onlyOwner {
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
        uint256 fixedFee
    ) public override onlyOwner {
        if (vaults[token].supported) revert Vault__Token_Already_Supported(token);

        vaults[token].wrappedToken = address(new WrappedToken(token));
        vaults[token].supported = true;
        vaults[token].creationTime = block.timestamp;
        vaults[token].baseFee = baseFee;
        vaults[token].fixedFee = fixedFee;

        emit TokenWasWhitelisted(token);
    }

    function whitelistTokenAndExec(
        address token,
        uint256 baseFee,
        uint256 fixedFee,
        bytes calldata data
    ) external override onlyOwner {
        whitelistToken(token, baseFee, fixedFee);
        (bool success, ) = token.delegatecall(data);
        assert(success);
    }

    function rebalanceInsurance(address token) external override returns (uint256 toTransfer) {
        VaultState.VaultData storage vault = vaults[token];
        IERC20 tkn = IERC20(token);
        uint256 optimalIR = ((tkn.balanceOf(address(this)) + vault.netLoans) * vault.optimalRatio) /
            VaultMath.RESOLUTION;
        uint256 insuranceReserveBalance = vault.insuranceReserveBalance;

        if (insuranceReserveBalance < optimalIR) revert Vault__Insurance_Below_OR(insuranceReserveBalance, optimalIR);

        toTransfer = insuranceReserveBalance - optimalIR;
        vault.insuranceReserveBalance -= toTransfer;

        tkn.safeTransfer(treasury, toTransfer);
    }

    function addInsurance(address token, uint256 amount)
        external
        override
        unlocked(token)
        isValidAmount(amount)
        onlyTreasury
    {
        checkWhitelisted(token);

        vaults[token].insuranceReserveBalance += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function stake(address token, uint256 amount) external override unlocked(token) isValidAmount(amount) {
        checkWhitelisted(token);
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);
        uint256 totalWealth = balance(token);

        (, amount) = IERC20(token).transferTokens(msg.sender, address(this), amount);

        uint256 toMint = wToken.mintWrapped(amount, msg.sender, totalWealth);

        emit Deposit(msg.sender, token, amount, toMint);
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

        uint256 toBurn = wToken.burnWrapped(amount, balance(token), msg.sender);

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount, toBurn);
    }

    function unstakeETH(uint256 amount) external override isValidAmount(amount) {
        checkWhitelisted(weth);

        IWrappedToken wToken = IWrappedToken(vaults[weth].wrappedToken);

        uint256 toBurn = wToken.burnWrapped(amount, balance(weth), msg.sender);
        IWETH(weth).withdraw(amount);

        (bool success, bytes memory data) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert Vault__ETH_Unstake_Failed(data); // reverts if unsuccessful

        emit Withdrawal(msg.sender, weth, amount, toBurn);
    }

    function treasuryStake(address token, uint256 amount) external override unlocked(token) isValidAmount(amount) {
        checkWhitelisted(token);

        vaults[token].addTreasuryLiquidity(IERC20(token), amount);
    }

    function treasuryUnstake(address token, uint256 amount)
        external
        override
        unlocked(token)
        isValidAmount(amount)
        onlyTreasury
    {
        checkWhitelisted(token);

        VaultState.VaultData storage vault = vaults[token];
        uint256 tol = vault.treasuryLiquidity;

        if (tol < amount) revert Vault__Insufficient_TOL(tol);

        vault.treasuryLiquidity -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    ) external override unlocked(token) onlyStrategy returns (uint256 baseInterestRate, uint256 fees) {
        checkWhitelisted(token);

        VaultState.VaultData storage vaultData = vaults[token];
        (uint256 freeLiquidity, ) = vaultData.takeLoan(IERC20(token), amount, riskFactor);

        baseInterestRate = VaultMath.computeInterestRateNoLeverage(
            vaultData.netLoans - amount,
            freeLiquidity,
            vaultData.insuranceReserveBalance,
            riskFactor,
            vaultData.baseFee
        );

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
