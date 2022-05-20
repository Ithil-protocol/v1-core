// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IExchange } from "./interfaces/IExchange.sol";

/// @title    Treasury contract
/// @author   Ithil
/// @notice   Responsible for APY boosts and governance decisions
contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    error Treasury__Insufficient_Wealth(address token, uint256 balance, uint256 wealth);
    error Treasury__Excessive_Airdrop(uint256 wealth, uint256 amount);
    error Treasury__Airdrop_Too_Recent(uint256 timestamp, uint256 lastAirdrop, uint256 interval);

    error Treasury__Swap_From_Taxed_Or_Wrong_Call();
    error Treasury__Swap_To_Taxed_Or_Wrong_Call();

    IVault public immutable vault;
    IERC20 public immutable governanceToken;
    address public immutable backingContract;
    IExchange public exchange;

    struct AirdropParameters {
        uint256 latestAirdrop;
        uint8 maximumAirdrop;
        uint16 airdropInterval;
    }

    AirdropParameters public airdropParameters;

    // treasuryWealth
    mapping(address => uint256) public treasuryWealth;

    constructor(
        address _vault,
        address _governanceToken,
        address _backingContract
    ) {
        vault = IVault(_vault);
        governanceToken = IERC20(_governanceToken);
        backingContract = _backingContract;
    }

    // Approves the vault to spend this particular token
    function approveToken(address token) external onlyOwner {
        IERC20(token).approve(address(vault), type(uint256).max);
    }

    function setAirdropParameters(uint8 _maximumAirdrop, uint16 _airdropInterval) external onlyOwner {
        airdropParameters.maximumAirdrop = _maximumAirdrop;
        airdropParameters.airdropInterval = _airdropInterval;
    }

    function setExchange(address _exchange) external onlyOwner {
        exchange = IExchange(_exchange);
    }

    // Stake and unstake functions do not distinguish between treasury and another LP
    function stake(address token, uint256 amount) external onlyOwner {
        vault.stake(token, amount);
    }

    function unstake(address token, uint256 amount) external onlyOwner {
        vault.unstake(token, amount);
    }

    function inject(address token, uint256 amount) external {
        treasuryWealth[token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function boostVault(
        address fromToken,
        address toToken,
        uint256 minAmountIn,
        bytes calldata data
    ) external onlyOwner {
        IERC20 tkn = IERC20(fromToken);
        uint256 balance = tkn.balanceOf(address(this));
        uint256 tWealth = treasuryWealth[fromToken];

        if (balance <= tWealth) revert Treasury__Insufficient_Wealth(fromToken, balance, tWealth);
        uint256 renounceAmount = balance - tWealth;

        if (fromToken != toToken) {
            uint256 initialBalanceFrom = tkn.balanceOf(address(this));
            uint256 initialBalanceTo = IERC20(toToken).balanceOf(address(this));
            uint256 amountIn = exchange.swap(renounceAmount, minAmountIn, data);

            if (tkn.balanceOf(address(this)) != initialBalanceFrom - renounceAmount)
                revert Treasury__Swap_From_Taxed_Or_Wrong_Call();

            if (IERC20(toToken).balanceOf(address(this)) <= initialBalanceTo + minAmountIn)
                revert Treasury__Swap_To_Taxed_Or_Wrong_Call();

            tkn.safeTransfer(address(vault), amountIn);
        } else tkn.safeTransfer(address(vault), renounceAmount);
    }

    function airdrop(address receiver, uint256 amount) external onlyOwner {
        uint256 tWealth = treasuryWealth[address(governanceToken)];

        // Check if airdrop exceeds maximum
        if (amount > (tWealth * airdropParameters.maximumAirdrop) / 100)
            revert Treasury__Excessive_Airdrop(tWealth, amount);

        // Check if latest airdrop was too recent
        if (block.timestamp < airdropParameters.latestAirdrop + airdropParameters.airdropInterval)
            revert Treasury__Airdrop_Too_Recent(
                block.timestamp,
                airdropParameters.latestAirdrop,
                airdropParameters.airdropInterval
            );

        airdropParameters.latestAirdrop = block.timestamp;
        treasuryWealth[address(governanceToken)] -= amount;

        governanceToken.safeTransfer(receiver, amount);
    }
}
