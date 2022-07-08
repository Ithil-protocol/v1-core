// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IKyberNetworkProxy } from "../interfaces/IKyberNetworkProxy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";

/// @dev Used for testing, unaudited
contract MockKyberNetworkProxy is IKyberNetworkProxy {
    using SafeERC20 for IERC20;

    mapping(IERC20 => uint256) internal rates;
    mapping(IERC20 => uint256) internal slippages;

    event PriceWasUpdated(address indexed token, uint256 oldRate, uint256 newRate);
    event SlippageWasUpdated(address indexed token, uint256 oldSlippage, uint256 newSlippage);

    function trade(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256, /*maxDestAmount*/
        uint256 minConversionRate,
        address payable platformWallet
    ) external payable override returns (uint256) {
        (uint256 destAmount, ) = getExpectedRate(src, dest, srcAmount);
        require(destAmount >= minConversionRate, "KyberMock: Tokens obtained below minimum");
        uint256 amountToDest = dest.balanceOf(destAddress);
        uint256 srcTokenAllowance = src.allowance(msg.sender, address(this));
        uint256 srcTokenBalance = src.balanceOf(msg.sender);

        require(srcTokenAllowance >= srcAmount, "KyberMock: Insufficient src token allowance");
        require(srcTokenBalance >= srcAmount, "KyberMock: Insufficient src token balance");

        src.safeTransferFrom(msg.sender, address(this), srcAmount);

        uint256 destTokenBalance = dest.balanceOf(address(this));
        require(destTokenBalance >= destAmount, "KyberMock: Insufficient dst token balance");

        dest.safeTransfer(destAddress, destAmount);
        platformWallet = payable(address(0));

        return dest.balanceOf(destAddress) - amountToDest;
    }

    function getExpectedRate(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount
    ) public view override returns (uint256, uint256) {
        if (address(src) == address(dest)) return (1, 1);
        uint256 srcDec = IERC20Metadata(address(src)).decimals();
        uint256 destDec = IERC20Metadata(address(dest)).decimals();
        uint256 rate1 = rates[src] * destDec;
        uint256 rate2 = rates[dest] * srcDec;
        if (rate2 == 0) return (0, 0);

        uint256 res = (srcAmount * rate1) / rate2;
        res = (res * (VaultMath.RESOLUTION - slippages[src])) / VaultMath.RESOLUTION;

        return (res, res);
    }

    function setRate(IERC20 token, uint256 rate) external {
        emit PriceWasUpdated(address(token), rates[token], rate);

        rates[token] = rate;
    }

    function setSlippage(IERC20 token, uint256 slippage) external {
        emit SlippageWasUpdated(address(token), slippages[token], slippage);

        slippages[token] = slippage;
    }
}
