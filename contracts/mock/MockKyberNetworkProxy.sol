// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IKyberNetworkProxy } from "../interfaces/IKyberNetworkProxy.sol";

contract MockKyberNetworkProxy is IKyberNetworkProxy {
    using SafeERC20 for IERC20;

    mapping(IERC20 => mapping(IERC20 => Rate)) internal rates;

    event PriceWasChanged(address indexed token0, address indexed token1, Rate oldRate, Rate newRate);

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
        Rate memory rate = rates[src][dest];

        uint256 res = (srcAmount * rate.numerator) / rate.denominator;

        return (res, res);
    }

    function setRate(
        IERC20 src,
        IERC20 dest,
        Rate calldata rate
    ) external {
        emit PriceWasChanged(address(src), address(dest), rates[src][dest], rate);

        rates[src][dest] = rate;
    }
}
