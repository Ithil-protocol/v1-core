// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";

/// @title    Liquidator contract
/// @author   Ithil
/// @notice   Base liquidation contract, can forcefully close base strategy's positions
contract Liquidator is Ownable {
    using SafeERC20 for IERC20;
    using GeneralMath for uint256;

    IERC20 public rewardToken;
    mapping(address => mapping(address => uint256)) public stakes;
    // maximumStake is always denominated in rewardToken
    uint256 public maximumStake;

    error Liquidator__Not_Enough_Ithil_Allowance(uint256 allowance);
    error Liquidator__Not_Enough_Ithil();
    error Liquidator__Unstaking_Too_Much(uint256 maximum);

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function setMaximumStake(uint256 amount) external onlyOwner {
        maximumStake = amount;
    }

    function setToken(address token) external onlyOwner {
        rewardToken = IERC20(token);
    }

    // The rewardToken only can be staked
    function stake(uint256 amount) external {
        uint256 allowance = rewardToken.allowance(msg.sender, address(this));
        if (rewardToken.balanceOf(msg.sender) < amount) revert Liquidator__Not_Enough_Ithil();
        if (allowance < amount) revert Liquidator__Not_Enough_Ithil_Allowance(allowance);
        stakes[address(rewardToken)][msg.sender] += amount;
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // When the token changes, people must be able to unstake the old one
    function unstake(address token, uint256 amount) external {
        uint256 staked = stakes[token][msg.sender];
        if (staked < amount) revert Liquidator__Unstaking_Too_Much(staked);
        stakes[token][msg.sender] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function liquidateSingle(IStrategy strategy, uint256 positionId) external {
        uint256 reward = rewardPercentage();
        strategy.forcefullyClose(positionId, msg.sender, reward);
    }

    function marginCall(
        IStrategy strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        uint256 reward = rewardPercentage();
        strategy.modifyCollateralAndOwner(positionId, extraMargin, msg.sender, reward);
    }

    function purchaseAssets(
        IStrategy strategy,
        uint256 positionId,
        uint256 price
    ) external {
        uint256 reward = rewardPercentage();
        strategy.transferAllowance(positionId, price, msg.sender, reward);
    }

    // rewardPercentage is computed as of the stakes of rewardTokens
    function rewardPercentage() public view returns (uint256) {
        if (maximumStake > 0) {
            uint256 stakePercentage = (stakes[address(rewardToken)][msg.sender] * VaultMath.RESOLUTION) / maximumStake;
            if (stakePercentage > VaultMath.RESOLUTION) return VaultMath.RESOLUTION;
            else return stakePercentage;
        } else {
            return 0;
        }
    }
}
