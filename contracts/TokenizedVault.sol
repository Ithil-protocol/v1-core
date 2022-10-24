// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import { GeneralMath } from "./libraries/GeneralMath.sol";

contract TokenizedVault is ERC4626, ERC20Permit, Ownable {
    using GeneralMath for uint256;

    struct VaultAccounting {
        uint256 netLoans;
        uint256 latestRepay;
        uint256 currentProfits;
    }

    uint256 public unlockTime;
    uint256 public immutable creationTime;
    bool public locked;
    VaultAccounting public vaultAccounting;

    constructor(address _token)
        ERC20(
            string(abi.encodePacked("Ithil ", IERC20Metadata(_token).name())),
            string(abi.encodePacked("i", IERC20Metadata(_token).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("Ithil ", IERC20Metadata(_token).name())))
        ERC4626(IERC20Metadata(_token))
    {
        creationTime = _blockTimestamp();
        unlockTime = 21600; // six hours
    }

    modifier unlocked() {
        if (locked) revert ERROR_Vault__Locked();
        _;
    }

    function toggleLock() external onlyOwner {
        locked = !locked;

        emit VaultLockWasToggled(locked);
    }

    function setUnlockTime(uint256 _unlockTime) external onlyOwner {
        // Minimum 30 seconds, maximum 7 days
        // This also avoids division by zero in _calculateLockedProfits()
        if (_unlockTime < 30 || _unlockTime > 604800) revert ERROR_Vault__Unlock_Out_Of_Range();
        unlockTime = _unlockTime;

        emit VaultLockWasToggled(locked);
    }

    // Total assets are used to calculate shares to mint and redeem
    // They represent the deposited (minted) and the unlocked fees
    function totalAssets() public view virtual override returns (uint256) {
        return super.totalAssets().protectedAdd(vaultAccounting.netLoans).positiveSub(_calculateLockedProfits());
    }

    // Free liquidity available to withdraw or borrow
    // Locked profits are locked for every operation
    function freeLiquidity() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)).positiveSub(_calculateLockedProfits());
    }

    // Assets include netLoans but they are not available for withdraw
    // Therefore we need to cap with the current free liquidity
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return freeLiquidity().min(super.maxWithdraw(owner));
    }

    // Deposit and mint are overridden to check locking and emit events

    function deposit(uint256 assets, address receiver) public virtual override unlocked returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);

        emit Deposited(_msgSender(), receiver, assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public virtual override unlocked returns (uint256) {
        uint256 assets = super.mint(shares, receiver);

        emit Deposited(_msgSender(), receiver, assets, shares);

        return assets;
    }

    // Throws 'ERC20: transfer amount exceeds balance' if
    // IERC20(asset()).balanceOf(address(this)) < assets
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        uint256 maximum = maxWithdraw(owner);
        if (assets > maximum) revert ERROR_Vault__Insufficient_Liquidity(maximum);
        uint256 shares = super.withdraw(assets, receiver, owner);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        uint256 maximum = maxWithdraw(owner);
        uint256 assets = super.redeem(shares, receiver, owner);
        if (assets > maximum) revert ERROR_Vault__Insufficient_Liquidity(maximum);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // Direct mint and burn are used to manage boosting and seniority in loans

    // Minting during a loss is equivalent to declaring the receiver senior
    // Minting dilutes stakers (damping)
    // Use case: treasury, backing contract...
    function directMint(uint256 shares, address receiver) external onlyOwner {
        _mint(receiver, shares);
    }

    // Burning during a loss is equivalent to declaring the owner junior
    // Burning undilutes stakers (boosting)
    // Use case: insurance reserve...
    function directBurn(uint256 shares, address owner) external onlyOwner {
        _spendAllowance(owner, _msgSender(), shares);
        _burn(owner, shares);
    }

    // Owner is the only trusted borrower
    function borrow(uint256 assets, address receiver) external onlyOwner {
        uint256 freeLiq = freeLiquidity();
        if (assets > freeLiq) revert ERROR_Vault__Insufficient_Free_Liquidity(freeLiq);
        vaultAccounting.netLoans += assets;
        IERC20(asset()).transfer(receiver, assets);

        emit Borrowed(receiver, assets);
    }

    // Owner is the only trusted repayer
    // amount may be greater or less than debt
    // Throws if repayer did not approve the vault
    // Throws if repayer does not have amount assets
    // _calculateLockedProfits() = vaultAccounting.currentProfits immediately after
    function repay(
        uint256 amount,
        uint256 debt,
        address repayer
    ) external onlyOwner {
        vaultAccounting.netLoans = vaultAccounting.netLoans.positiveSub(debt);

        // any excess amount is considered to be fees
        // if a bad debt has beed repaid, we recover part from the locked profits
        // totalAssets() stay constant unless debt - amount > _calculateLockedProfits()
        vaultAccounting.currentProfits = amount > debt
            ? _calculateLockedProfits() + amount - debt
            : _calculateLockedProfits().positiveSub(debt - amount);
        vaultAccounting.latestRepay = _blockTimestamp();

        // the vault is not responsible for any payoff
        IERC20(asset()).transferFrom(repayer, address(this), amount);

        emit Repaid(repayer, amount, debt);
    }

    function _calculateLockedProfits() internal view returns (uint256) {
        uint256 profits = vaultAccounting.currentProfits;
        return profits.positiveSub(((_blockTimestamp() - vaultAccounting.latestRepay) * profits) / unlockTime);
    }

    // overridden in tests
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // Events

    event GuardianWasUpdated(address guardian);

    event VaultLockWasToggled(bool locked);

    event DegradationCoefficientChanged(uint256 degradationCoefficient);

    event Deposited(address indexed user, address indexed receiver, uint256 assets, uint256 shares);

    event Withdrawn(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Borrowed(address indexed receiver, uint256 assets);

    event Repaid(address indexed repayer, uint256 amount, uint256 debt);

    // Errors
    error ERROR_Vault__Insufficient_Liquidity(uint256 balance);
    error ERROR_Vault__Insufficient_Free_Liquidity(uint256 freeLiquidity);
    error ERROR_Vault__Unlock_Out_Of_Range();
    error ERROR_Vault__Only_Guardian();
    error ERROR_Vault__Locked();
}
