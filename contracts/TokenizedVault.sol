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
        uint256 boostedAmount;
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
        unlockTime = _unlockTime;

        emit VaultLockWasToggled(locked);
    }

    // Total assets are used to calculate shares to mint and redeem
    // They represent the deposited (minted) and the unlocked fees
    function totalAssets() public view virtual override returns (uint256) {
        return
            super
                .totalAssets()
                .protectedAdd(vaultAccounting.netLoans)
                .positiveSub(vaultAccounting.boostedAmount)
                .positiveSub(_calculateLockedProfits());
    }

    function boost(address owner, uint256 assets) public onlyOwner {
        vaultAccounting.boostedAmount += assets;
        IERC20(asset()).transferFrom(owner, address(this), assets);

        emit Boosted(owner, assets);
    }

    function unboost(address receiver, uint256 assets) public onlyOwner {
        IERC20 asset = IERC20(asset());
        uint256 currentBoosted = vaultAccounting.boostedAmount;
        // Withdraw the maximum possible: min(assets, boosted, balance)
        uint256 toWithdraw = assets.min(currentBoosted).min(asset.balanceOf(address(this)));
        // Since toWithdraw <= currentBoosted, we can skip the underflow check
        vaultAccounting.boostedAmount -= toWithdraw;
        // Since toWithdraw <= asset.balanceOf(address(this)), the following never reverts
        asset.transfer(receiver, toWithdraw);

        emit Unboosted(receiver, toWithdraw);
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

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        uint256 shares = super.withdraw(assets, receiver, owner);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        uint256 assets = super.redeem(shares, receiver, owner);

        emit Withdrawn(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // The owner is the only trusted borrower
    // Throws if IERC20(asset()).balanceOf(address(this)) < assets
    function borrow(uint256 assets, address receiver) public onlyOwner {
        vaultAccounting.netLoans += assets;
        IERC20(asset()).transfer(receiver, assets);

        emit Borrowed(receiver, assets);
    }

    // The owner is the only trusted repayer
    // amount may be greater or less than debt
    // therefore we need two parameters
    // Throws if repayer did not approve the vault
    // Throws if repayer does not have amount assets
    // _calculateLockedProfits() = vaultAccounting.currentProfits immediately after
    function repay(
        uint256 amount,
        uint256 debt,
        address repayer
    ) public onlyOwner {
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

    event BoosterWasSet(address booster);

    event GuardianWasUpdated(address guardian);

    event VaultLockWasToggled(bool locked);

    event DegradationCoefficientChanged(uint256 degradationCoefficient);

    event Boosted(address owner, uint256 assets);

    event Unboosted(address receiver, uint256 assets);

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
    error ERROR_Vault__Only_Guardian();
    error ERROR_Vault__Only_Booster();
    error ERROR_Vault__Locked();
}
