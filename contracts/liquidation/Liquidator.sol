// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";
import { VaultMath } from "../libraries/VaultMath.sol";
import { GeneralMath } from "../libraries/GeneralMath.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";

/// @title    Liquidator contract
/// @author   Ithil
/// @notice   Base liquidation contract, can forcefully close base strategy's positions
contract Liquidator is Ownable {
    using SafeERC20 for IERC20;
    using TransferHelper for IERC20;
    using GeneralMath for uint256;

    IERC20 public immutable ithil;
    mapping(address => uint256) public stakes;
    uint256 public maximumStake;

    error Liquidator__Not_Enough_Ithil_Allowance(uint256 allowance);
    error Liquidator__Not_Enough_Ithil();
    error Liquidator__Unstaking_Too_Much(uint256 maximum);

    constructor(address _ithil) {
        ithil = IERC20(_ithil);
    }

    function setMaximumStake(uint256 amount) external onlyOwner {
        maximumStake = amount;
    }

    function stake(uint256 amount) external {
        uint256 allowance = ithil.allowance(msg.sender, address(this));
        if (ithil.balanceOf(msg.sender) < amount) revert Liquidator__Not_Enough_Ithil();
        if (allowance < amount) revert Liquidator__Not_Enough_Ithil_Allowance(allowance);
        stakes[msg.sender] += amount;
        ithil.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        uint256 staked = stakes[msg.sender];
        if (staked < amount) revert Liquidator__Unstaking_Too_Much(staked);
        stakes[msg.sender] -= amount;
        ithil.safeTransfer(msg.sender, amount);
    }

    function liquidateSingle(IStrategy strategy, uint256 positionId) external {
        //todo: add checks on liquidator
        uint256 reward = rewardPercentage();
        strategy.forcefullyClose(positionId, msg.sender, reward);
    }

    function marginCall(
        IStrategy strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        //todo: add checks on liquidator
        uint256 reward = rewardPercentage();
        strategy.modifyCollateralAndOwner(positionId, extraMargin, msg.sender, reward);
    }

    function purchaseAssets(
        IStrategy strategy,
        uint256 positionId,
        uint256 price
    ) external {
        //todo: add checks on liquidator
        uint256 reward = rewardPercentage();
        strategy.forcefullyDelete(positionId, price, msg.sender, reward);
    }

    function rewardPercentage() public view returns (uint256) {
        if (maximumStake > 0) {
            uint256 stakePercentage = (stakes[msg.sender] * VaultMath.RESOLUTION) / maximumStake;
            if (stakePercentage > VaultMath.RESOLUTION) return VaultMath.RESOLUTION;
            else return (stakes[msg.sender] * VaultMath.RESOLUTION) / maximumStake;
        } else return 0;
    }
}
