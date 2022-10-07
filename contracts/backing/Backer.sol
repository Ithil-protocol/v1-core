// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BidPrice } from "./libraries/BidPrice.sol";

contract Backer is Ownable {
    using BidPrice for uint256;

    IERC20 public immutable numeraire;
    IERC20 public immutable native;

    mapping(address => bool) public purchaser;

    constructor(address _numeraire, address _native) {
        numeraire = IERC20(_numeraire);
        native = IERC20(_native);
    }

    modifier nonZero(uint256 amount) {
        if (amount == 0) revert Backer__Zero_Amount();
        _;
    }

    modifier onlyPurchaser() {
        if (!purchaser[msg.sender]) revert Backer__Not_Purchaser();
        _;
    }

    /// ADMIN

    /// @notice allows or de-allows purchaser to purchase tokens at the bid price
    function togglePurchaser(address _purchaser) external onlyOwner {
        purchaser[_purchaser] = !purchaser[_purchaser];
        emit SetPurchaser(_purchaser, purchaser[_purchaser]);
    }

    /// PURCHASE

    /// @notice purchases exact amount of native tokens at the bid price and sends them to recipient
    /// @dev throws if msg.sender is not a purchaser
    /// bid price in, so we round up
    function purchaseExactNat(uint256 toPurchase, address recipient) external nonZero(toPurchase) onlyPurchaser {
        uint256 bidPrice = toPurchase.computeBidPriceCeil(
            numeraire.balanceOf(address(this)),
            native.balanceOf(address(this)),
            native.totalSupply()
        );
        numeraire.transferFrom(msg.sender, address(this), bidPrice);
        native.transfer(recipient, toPurchase);
        emit Purchased(bidPrice, toPurchase);
    }

    /// @notice purchases native tokens with an exact amount of numeraire tokens
    /// to purchase out, so we round down
    function purchaseExactNum(uint256 toSpend, address recipient) external onlyPurchaser {
        uint256 toPurchase = toSpend.computeInverseBidPriceFloor(
            numeraire.balanceOf(address(this)),
            native.balanceOf(address(this)),
            native.totalSupply()
        );
        numeraire.transferFrom(msg.sender, address(this), toSpend);
        native.transfer(recipient, toPurchase);
        emit Purchased(toSpend, toPurchase);
    }

    /// REDEEM

    /// @notice redeems exact amount of native tokens for numeraire tokens and sends them to recipient
    /// bid price out, so we round down
    function redeemExactNat(uint256 toRedeem, address recipient) external {
        uint256 bidPrice = toRedeem.computeBidPriceFloor(
            numeraire.balanceOf(address(this)),
            native.balanceOf(address(this)),
            native.totalSupply()
        );
        native.transferFrom(msg.sender, address(this), toRedeem);
        numeraire.transfer(recipient, bidPrice);
        emit Redeemed(bidPrice, toRedeem);
    }

    /// @notice redeems exact amount of numeraire tokens for native tokens and sends them to recipient
    /// toRedeem in, so we round up
    function redeemExactNum(uint256 toObtain, address recipient) external nonZero(toObtain) {
        uint256 toRedeem = toObtain.computeInverseBidPriceCeil(
            numeraire.balanceOf(address(this)),
            native.balanceOf(address(this)),
            native.totalSupply()
        );
        native.transferFrom(msg.sender, address(this), toRedeem);
        numeraire.transfer(recipient, toObtain);
        emit Redeemed(toObtain, toRedeem);
    }

    error Backer__Purchase_Too_Much(uint256 balance);
    error Backer__Impossible_Deposit();
    error Backer__Zero_Amount();
    error Backer__Not_Purchaser();

    event SetPurchaser(address purchaser, bool canPurchase);
    event Purchased(uint256 numeraireIn, uint256 nativeOut);
    event Redeemed(uint256 numeraireOut, uint256 nativeIn);
}
