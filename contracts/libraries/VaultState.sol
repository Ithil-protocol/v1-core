// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GeneralMath } from "./GeneralMath.sol";
import { VaultMath } from "./VaultMath.sol";
import { BridgeHelper } from "./BridgeHelper.sol";

/// @title    VaultState library
/// @author   Ithil
/// @notice   A library to store the vault status
library VaultState {
    using SafeERC20 for IERC20;
    using BridgeHelper for IERC20;
    using GeneralMath for uint256;

    error Vault__Insufficient_Free_Liquidity(address token, uint256 requested, uint256 freeLiquidity);

    /// @notice store data about whitelisted tokens
    /// @param supported Easily check if a token is supported or not (null VaultData struct)
    /// @param locked Whether the token is locked - can only be withdrawn
    /// @param wrappedToken Address of the corresponding WrappedToken
    /// @param creationTime block timestamp of the subvault and relative WrappedToken creation
    /// @param baseFee
    /// @param fixedFee
    /// @param minimumMargin The minimum margin needed to open a position
    /// @param boostedAmount Total amount of liquidity redirecting their APY to the other stakers
    /// @param netLoans Total amount of liquidity currently lent to traders
    /// @param insuranceReserveBalance Total amount of liquidity left as insurance
    /// @param optimalRatio The optimal ratio of the insurance reserve
    /// @param latestRepay Last time staking rewards were redistributed
    /// @param currentProfits Amount of locked profits that will be released in the next hours
    ///                       to the stakers
    struct VaultData {
        bool supported;
        bool locked;
        address wrappedToken;
        uint256 creationTime;
        uint256 baseFee;
        uint256 fixedFee;
        uint256 minimumMargin;
        uint256 boostedAmount;
        uint256 netLoans;
        uint256 insuranceReserveBalance;
        uint256 optimalRatio;
        uint256 latestRepay;
        uint256 currentProfits;
    }

    function addInsuranceReserve(
        VaultState.VaultData storage self,
        uint256 totalBalance,
        uint256 fees
    ) internal returns (uint256) {
        uint256 availableInsuranceBalance = self.insuranceReserveBalance.positiveSub(self.netLoans);
        uint256 insurancePortion = (fees * self.optimalRatio * (totalBalance - availableInsuranceBalance)) /
            (totalBalance * VaultMath.RESOLUTION);
        self.insuranceReserveBalance += insurancePortion;

        return insurancePortion;
    }

    function takeLoan(
        VaultState.VaultData storage self,
        IERC20 token,
        uint256 amount,
        uint256 riskFactor,
        uint256 destinationChainId,
        address bridge
    ) internal returns (uint256) {
        uint256 totalRisk = self.optimalRatio * self.netLoans;
        self.netLoans += amount;
        self.optimalRatio = (totalRisk + amount * riskFactor) / self.netLoans;

        // If the following fails drainage has occurred so we want failure
        uint256 freeLiquidity = IERC20(token).balanceOf(address(this)) - self.insuranceReserveBalance;

        if (amount > freeLiquidity) revert Vault__Insufficient_Free_Liquidity(address(token), amount, freeLiquidity);

        // check if it is a cross-chain transfer
        if (destinationChainId != 0) {
            uint32 destinationDomain = BridgeHelper.getDomain(destinationChainId);

            BridgeHelper.bridgedTransfer(token, bridge, msg.sender, amount, amount, destinationDomain);
        } else {
            token.safeTransfer(msg.sender, amount);
        }

        // We have transferred an amount <= freeLiquidity, therefore we now have
        // IERC20(token).balanceOf(address(this)) >= self.insuranceReserveBalance
        return freeLiquidity;
    }

    function subtractLoan(VaultState.VaultData storage self, uint256 b) private {
        if (self.netLoans > b) self.netLoans -= b;
        else self.netLoans = 0;
    }

    function subtractInsuranceReserve(VaultState.VaultData storage self, uint256 b) private {
        self.insuranceReserveBalance = self.insuranceReserveBalance.positiveSub(b);
    }

    function repayLoan(
        VaultState.VaultData storage self,
        IERC20 token,
        address borrower,
        uint256 debt,
        uint256 fees,
        uint256 amount,
        uint256 riskFactor,
        uint256 destinationChainId,
        address bridge
    ) internal returns (uint256) {
        uint256 amountToTransfer = 0;
        uint256 totalRisk = self.optimalRatio * self.netLoans;
        subtractLoan(self, debt);
        self.optimalRatio = self.netLoans != 0 ? totalRisk.positiveSub(riskFactor * debt) / self.netLoans : 0;
        if (amount >= debt + fees) {
            // At this point amount has been transferred here
            // Insurance reserve increases by a portion of fees
            uint256 insurancePortion = addInsuranceReserve(self, token.balanceOf(address(this)), fees);
            self.currentProfits =
                VaultMath.calculateLockedProfit(self.currentProfits, block.timestamp, self.latestRepay);
            self.currentProfits +=
                fees -
                insurancePortion;
            self.latestRepay = block.timestamp;
            amountToTransfer = amount - debt - fees;
            // Since fees >= insurancePortion, we still have
            // token.balanceOf(address(this)) >= self.insuranceReserveBalance;
        } else {
            // Bad liquidation: rewards the liquidator with 5% of the amountIn
            // amount is already adjusted in BaseStrategy
            if (amount < debt) subtractInsuranceReserve(self, debt - amount);
            amountToTransfer = amount / 19;
        }

        if(destinationChainId != 0) {
            uint32 destinationDomain = BridgeHelper.getDomain(destinationChainId);
            BridgeHelper.bridgedTransfer(token, bridge, borrower, amount, amount, destinationDomain);
        } else {
            token.safeTransfer(borrower, amountToTransfer);
        }

        return amountToTransfer;
    }
}
