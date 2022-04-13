// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IVault } from "./interfaces/IVault.sol";
import { IWrappedToken } from "./interfaces/IWrappedToken.sol";
import { VaultMath } from "./libraries/VaultMath.sol";
import { VaultState } from "./libraries/VaultState.sol";
import { GeneralMath } from "./libraries/GeneralMath.sol";
import { WrappedToken } from "./WrappedToken.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

/// @title    Vault contract
/// @author   Ithil
/// @notice   Stores staked funds, issues loans and handles repayments to strategies
contract Vault is IVault, ReentrancyGuard, Ownable {
    using TransferHelper for IERC20;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;
    using VaultMath for uint256;
    using GeneralMath for uint256;
    using GeneralMath for VaultState.VaultData;
    using VaultState for VaultState.VaultData;

    address internal immutable weth;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => VaultState.VaultData) public vaults;
    mapping(address => bool) public strategies;

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

    modifier whitelisted(address token) {
        if (!vaults[token].supported && token != ETH) revert Vault__Unsupported_Token(token);
        _;
    }

    modifier onlyStrategy() {
        if (!strategies[msg.sender]) revert Vault__Restricted_Access(msg.sender);
        _;
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        if (msg.sender != weth) revert Vault__ETH_Transfer_Failed();
    }

    function balance(address token) public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this)) + vaults[token].netLoans - vaults[token].insuranceReserveBalance;
    }

    function claimable(address token) external view override whitelisted(token) returns (uint256) {
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

    function stake(address token, uint256 amount)
        external
        override
        whitelisted(token)
        unlocked(token)
        isValidAmount(amount)
    {
        uint256 totalWealth = balance(token);
        (, amount) = IERC20(token).transferTokens(msg.sender, address(this), amount);

        _stakeAndMint(token, amount, msg.sender, totalWealth);
    }

    function stakeETH(uint256 amount) external payable override whitelisted(weth) unlocked(weth) isValidAmount(amount) {
        if (msg.value != amount) revert Vault__Insufficient_ETH();

        uint256 totalWealth = balance(weth);
        IWETH(weth).deposit{ value: amount }();

        _stakeAndMint(weth, amount, msg.sender, totalWealth);
    }

    function _stakeAndMint(
        address token,
        uint256 amount,
        address user,
        uint256 totalWealth
    ) internal {
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);
        uint256 oldCp = wToken.balanceOf(user);
        uint256 toMint = VaultMath.claimingPowerAfterDeposit(amount, oldCp, wToken.totalSupply(), totalWealth);
        toMint -= oldCp;
        wToken.mint(user, toMint);

        emit Deposit(user, token, amount, toMint);
    }

    function unstake(address token, uint256 amount) external override whitelisted(token) isValidAmount(amount) {
        _unstakeAndBurn(token, amount, msg.sender);

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function unstakeETH(uint256 amount) external override whitelisted(weth) isValidAmount(amount) {
        _unstakeAndBurn(weth, amount, msg.sender);

        IWETH tkn = IWETH(weth);
        tkn.withdraw(amount);
        payable(msg.sender).transfer(amount); // reverts if unsuccessful
    }

    function _unstakeAndBurn(
        address token,
        uint256 amount,
        address user
    ) internal {
        IWrappedToken wToken = IWrappedToken(vaults[token].wrappedToken);

        uint256 senderCp = wToken.balanceOf(user);
        uint256 totalClaims = wToken.totalSupply();
        uint256 totalWealth = balance(token);

        if (amount > VaultMath.maximumWithdrawal(senderCp, totalClaims, totalWealth))
            revert Vault__Max_Withdrawal(user, token);

        uint256 toBurn = (senderCp -
            VaultMath.claimingPowerAfterWithdrawal(amount, senderCp, totalClaims, totalWealth));
        wToken.burn(user, toBurn);

        emit Withdrawal(user, token, amount, toBurn);
    }

    function borrow(
        address token,
        uint256 amount,
        uint256 riskFactor,
        address borrower
    )
        external
        override
        whitelisted(token)
        unlocked(token)
        onlyStrategy
        returns (uint256 baseInterestRate, uint256 fees)
    {
        VaultState.VaultData storage vaultData = vaults[token];
        (uint256 freeLiquidity, ) = vaultData.takeLoan(IERC20(token), amount);

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
        address borrower
    ) external override whitelisted(token) onlyStrategy {
        VaultState.VaultData storage vaultData = vaults[token];

        vaultData.repayLoan(IERC20(token), borrower, debt, fees, amount);

        emit LoanRepaid(borrower, token, amount);
    }
}
