// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import { GeneralMath } from "./libraries/GeneralMath.sol";

contract TokenizedVault is ERC4626, ERC20Permit, Ownable {
    using GeneralMath for uint256;
    using SafeERC20 for IERC20;

    struct VaultAccounting {
        uint256 netLoans;
        uint256 latestRepay;
        int256 currentProfits;
    }

    uint256 public unlockTime;
    uint256 public immutable creationTime;
    bool public locked;
    VaultAccounting public vaultAccounting;

    constructor(IERC20Metadata _token)
        ERC20(
            string(abi.encodePacked("Ithil ", _token.name())),
            string(abi.encodePacked("i", _token.symbol()))
        )
        ERC20Permit(string(abi.encodePacked("Ithil ", _token.name())))
        ERC4626(_token)
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
    // They represent the deposited amount, the loans and the unlocked fees
    // As per ERC4626 standard this must never throw, thus we use protected math
    // totalAssets() must adjust so that maxWithdraw() is an invariant for all functions
    // As profits unlock, assets increase or decrease
    function totalAssets() public view virtual override returns (uint256) {
        int256 lockedProfits = _calculateLockedProfits();
        return
            lockedProfits > 0
                ? super.totalAssets().protectedAdd(vaultAccounting.netLoans).positiveSub(uint256(lockedProfits))
                : super.totalAssets().protectedAdd(vaultAccounting.netLoans).protectedAdd(uint256(-lockedProfits));
    }

    // Free liquidity available to withdraw or borrow
    // Locked profits are locked for every operation
    // We do not consider negative profits since they are not true liquidity
    function freeLiquidity() public view returns (uint256) {
        int256 lockedProfits = _calculateLockedProfits();
        return
            lockedProfits > 0
                ? IERC20(asset()).balanceOf(address(this)).positiveSub(uint256(lockedProfits))
                : IERC20(asset()).balanceOf(address(this));
    }

    // Assets include netLoans but they are not available for withdraw
    // Therefore we need to cap with the current free liquidity
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return freeLiquidity().min(super.maxWithdraw(owner));
    }

    // Deposit and mint are overridden to check locking and emit events
    // Throws if IERC20(asset()).allowance(_msgSender(), vault) < assets
    function deposit(uint256 assets, address receiver) public virtual override unlocked returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);

        emit Deposited(_msgSender(), receiver, assets, shares);

        return shares;
    }

    // Depositor must first approve the vault to spend IERC20(asset())
    // Throws if IERC20(asset()).allowance(_msgSender(), vault) < assets
    function mint(uint256 shares, address receiver) public virtual override unlocked returns (uint256) {
        uint256 assets = super.mint(shares, receiver);

        emit Deposited(_msgSender(), receiver, assets, shares);

        return assets;
    }

    // Throws 'ERC20: transfer amount exceeds balance' if
    // IERC20(asset()).balanceOf(address(this)) < assets
    // Needs approvals if caller is not owner
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        // Due to ERC4626 collateralization constraint, we must enforce impossibility of zero balance
        // Therefore we need to revert if assets >= freeLiq rather than assets > freeLiq
        uint256 freeLiq = freeLiquidity();
        if (assets >= freeLiq) revert ERROR_Vault__Insufficient_Liquidity(freeLiq);
        uint256 shares = super.withdraw(assets, receiver, owner);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // Needs approvals if caller is not owner
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        uint256 freeLiq = freeLiquidity();
        uint256 assets = super.redeem(shares, receiver, owner);
        if (assets >= freeLiq) revert ERROR_Vault__Insufficient_Liquidity(freeLiq);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // Direct mint and burn are used to manage boosting and seniority in loans

    // Minting during a loss is equivalent to declaring the receiver senior
    // Minting dilutes stakers (damping)
    // Use case: treasury, backing contract...
    // Invariant: maximumWithdraw(account) for account != receiver
    function directMint(uint256 shares, address receiver) external onlyOwner {
        // When minting, the receiver assets increase
        // Thus we produce negative profits and we need to lock them
        uint256 increasedAssets = convertToAssets(shares);
        _mint(receiver, shares);

        vaultAccounting.currentProfits = _calculateLockedProfits() - int256(increasedAssets);
        vaultAccounting.latestRepay = _blockTimestamp();

        emit DirectMint(receiver, shares, increasedAssets);
    }

    // Burning during a loss is equivalent to declaring the owner junior
    // Burning undilutes stakers (boosting)
    // Use case: insurance reserve...
    // Invariant: maximumWithdraw(account) for account != receiver
    function directBurn(uint256 shares, address owner) external onlyOwner {
        // Burning the entire supply would trigger an _initialConvertToShares at next deposit
        // Meaning that the first to deposit will get everything
        // To avoid overriding _initialConvertToShares, we make the following check
        if (shares >= totalSupply()) revert ERROR_Vault__Supply_Burned();

        // When burning, the owner assets are distributed to others
        // Thus we need to lock them in order to avoid flashloan attacks
        uint256 distributedAssets = convertToAssets(shares);

        _spendAllowance(owner, _msgSender(), shares);
        _burn(owner, shares);

        // Since this is onlyOwner we are not worried about reentrancy
        // So we can modify the state here
        vaultAccounting.currentProfits = _calculateLockedProfits() + int256(distributedAssets);
        vaultAccounting.latestRepay = _blockTimestamp();

        emit DirectBurn(owner, shares, distributedAssets);
    }

    // Owner is the only trusted borrower
    // Invariant: totalAssets(), maxWithdraw()
    function borrow(uint256 assets, address receiver) external onlyOwner {
        uint256 freeLiq = freeLiquidity();
        // At the very worst case, the borrower repays nothing
        // In this case we need to avoid division by zero by putting >= rather than >
        if (assets >= freeLiq) revert ERROR_Vault__Insufficient_Free_Liquidity(freeLiq);
        vaultAccounting.netLoans += assets;
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Borrowed(receiver, assets);
    }

    // Owner is the only trusted repayer
    // Transfers amount from repayer to the vault
    // amount may be greater or less than debt
    // Throws if repayer did not approve the vault
    // Throws if repayer does not have amount assets
    // _calculateLockedProfits() = vaultAccounting.currentProfits immediately after
    // Invariant: totalAssets()
    // maxWithdraw() is invariant as long as totalAssets()-currentProfits >= native.balanceOf(this)
    function repay(
        uint256 amount,
        uint256 debt,
        address repayer
    ) external onlyOwner {
        vaultAccounting.netLoans = vaultAccounting.netLoans.positiveSub(debt);

        // any excess amount is considered to be fees
        // if a bad debt has beed repaid, we recover part from the locked profits
        // similarly, if lockedProfits < 0, a good repay can recover them
        vaultAccounting.currentProfits = _calculateLockedProfits() + int256(amount) - int256(debt);
        vaultAccounting.latestRepay = _blockTimestamp();

        // the vault is not responsible for any payoff
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(asset()).safeTransferFrom(repayer, address(this), amount);

        emit Repaid(repayer, amount, debt);
    }

    // Starts from currentProfits and go linearly to 0
    // It is zero when _blockTimestamp()-latestRepay > unlockTime
    function _calculateLockedProfits() internal view returns (int256) {
        return
            (vaultAccounting.currentProfits *
                int256(unlockTime.positiveSub(_blockTimestamp() - vaultAccounting.latestRepay))) / int256(unlockTime);
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

    event DirectMint(address indexed receiver, uint256 shares, uint256 increasedAssets);

    event DirectBurn(address indexed receiver, uint256 shares, uint256 distributedAssets);
    // Errors
    error ERROR_Vault__Insufficient_Liquidity(uint256 balance);
    error ERROR_Vault__Insufficient_Free_Liquidity(uint256 freeLiquidity);
    error ERROR_Vault__Supply_Burned();
    error ERROR_Vault__Unlock_Out_Of_Range();
    error ERROR_Vault__Only_Guardian();
    error ERROR_Vault__Locked();
}
