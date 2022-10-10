// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

library BidPrice {
    /// @notice computes bid price, in numeraire tokens, of an amount of native tokens with floor division
    /// @notice returns a number with numeraire token decimals
    /// @dev throws if nativeSupply <= nativeBalance (impossible to redeem: no tokens outside);
    /// @param amount the amount of native tokens to compute the price of (decimals: native)
    /// @param numBalance the current numeraire token balance of the backing (decimals: numeraire)
    /// @param nativeBalance the current native token balance of the backing (decimals: native)
    /// @param nativeSupply the total native token supply(decimals: native)
    function computeBidPriceFloor(
        uint256 amount,
        uint256 numBalance,
        uint256 nativeBalance,
        uint256 nativeSupply
    ) internal pure returns (uint256) {
        if (amount > 0) return (amount * numBalance) / (nativeSupply - nativeBalance);
        else return 0;
    }

    /// @notice computes bid price, in numeraire tokens, of an amount of native tokens with ceiling division
    /// @notice returns a number with native token decimals
    /// @dev throws if nativeSupply <= nativeBalance (impossible to redeem: no tokens outside)
    /// @dev throws if numBalance = 0 (bid price 0 would mean free tokens);
    function computeBidPriceCeil(
        uint256 amount,
        uint256 numBalance,
        uint256 nativeBalance,
        uint256 nativeSupply
    ) internal pure returns (uint256) {
        if (amount > 0) return 1 + (amount * numBalance - 1) / (nativeSupply - nativeBalance);
        else return 0;
    }

    /// @notice computes how many native tokens is worth amount of numeraire tokens with floor division
    /// @dev returns a number with native token decimals
    /// @param amount the amount of numeraire tokens to compute the value of (decimals: numeraire)
    /// @param numBalance the current numeraire token balance of the backing (decimals: numeraire)
    /// @param nativeBalance the current native token balance of the backing (decimals: native)
    /// @param nativeSupply the total native token supply(decimals: native)
    /// @dev throws if numBalance = 0;
    function computeInverseBidPriceFloor(
        uint256 amount,
        uint256 numBalance,
        uint256 nativeBalance,
        uint256 nativeSupply
    ) internal pure returns (uint256) {
        if (amount > 0) return (amount * (nativeSupply - nativeBalance)) / numBalance;
        else return 0;
    }

    /// @notice computes how many native tokens is worth amount of numeraire tokens with ceiling division
    /// @dev returns a number with native token decimals
    /// @param amount the amount of numeraire tokens to compute the value of (decimals: numeraire)
    /// @param numBalance the current numeraire token balance of the backing (decimals: numeraire)
    /// @param nativeBalance the current native token balance of the backing (decimals: native)
    /// @param nativeSupply the total native token supply(decimals: native)
    /// @dev throws if numBalance = 0, amount = 0 or nativeSupply <= nativeBalance;
    function computeInverseBidPriceCeil(
        uint256 amount,
        uint256 numBalance,
        uint256 nativeBalance,
        uint256 nativeSupply
    ) internal pure returns (uint256) {
        if (amount > 0) return 1 + (amount * (nativeSupply - nativeBalance) - 1) / numBalance;
        else return 0;
    }
}
