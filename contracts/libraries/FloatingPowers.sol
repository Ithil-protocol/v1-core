// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

library FloatingPowers {
    // Assumes numbers have 18 decimals
    uint256 internal constant ONE = 1e18;

    function floatingMul(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * y) / ONE;
    }

    function floatingDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x * ONE) / y;
    }

    function complement(uint256 x) internal pure returns (uint256) {
        return x < ONE ? ONE - x : 0;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        // Fixed Point addition is the same as regular checked addition

        require(b <= a, "SUB_OVERFLOW");
        uint256 c = a - b;
        return c;
    }

    // Assumes base is "near 10^18", as it will be the case for the typical Balancer pools
    // Balancer's math module also uses Taylor expansion, thus they also assume small numbers
    // exp is also a floating number, as the normalized weights of Balancer pools
    // 2-th order Taylor expansion
    function floatingPower(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 mantissa = base > ONE ? base - ONE : ONE - base;

        // First order is already quite near
        uint256 firstOrder = base > ONE ? ONE + floatingMul(mantissa, exp) : ONE - floatingMul(mantissa, exp);

        uint256 firstNum = exp > ONE ? exp * (exp - ONE) * (mantissa**2) : exp * (ONE - exp) * (mantissa**2);
        uint256 firstDen = 2 * (ONE**3);
        uint256 secondOrder = exp > ONE ? firstOrder + firstNum / firstDen : firstOrder - firstNum / firstDen;

        return secondOrder;
    }

    function computeBptOut(
        uint256 amountIn,
        uint256 totalBptSupply,
        uint256 totalTokenBalance,
        uint256 normalizedWeight,
        uint256 swapPercentageFee
    ) internal pure returns (uint256) {
        uint256 swapFee = floatingMul(floatingMul(amountIn, ONE - normalizedWeight), swapPercentageFee);
        uint256 balanceRatio = floatingDiv(totalTokenBalance + amountIn - swapFee, totalTokenBalance);
        uint256 invariantRatio = floatingPower(balanceRatio, normalizedWeight);
        return invariantRatio > ONE ? floatingMul(totalBptSupply, invariantRatio - ONE) : 0;
    }

    function computeAmountOut(
        uint256 amountIn,
        uint256 totalBptSupply,
        uint256 totalTokenBalance,
        uint256 normalizedWeight,
        uint256 swapPercentageFee
    ) internal pure returns (uint256) {
        uint256 invariantRatio = floatingDiv(totalBptSupply - amountIn, totalBptSupply);
        uint256 balanceRatio = floatingPower(invariantRatio, floatingDiv(ONE, normalizedWeight));
        uint256 amountOutWithoutFee = floatingMul(totalTokenBalance, complement(balanceRatio));
        uint256 taxableAmount = floatingMul(amountOutWithoutFee, complement(normalizedWeight));
        uint256 nonTaxableAmount = sub(amountOutWithoutFee, taxableAmount);
        uint256 taxableAmountMinusFees = floatingMul(taxableAmount, complement(swapPercentageFee));

        return nonTaxableAmount + taxableAmountMinusFees;
    }
}
