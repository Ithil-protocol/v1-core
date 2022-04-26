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

    address public immutable ithil;
    mapping(address => uint256) public stakes;
    uint256 public maximumStake;

    error Liquidator__Not_Enough_Ithil_Allowance(uint256 allowance);
    error Liquidator__Not_Enough_Ithil();
    error Liquidator__Unstaking_Too_Much(uint256 maximum);

    constructor(address _ithil) {
        ithil = _ithil;
    }

    function setMaximumStake(uint256 amount) external onlyOwner {
        maximumStake = amount;
    }

    function stake(uint256 amount) external {
        IERC20 ith = IERC20(ithil);
        uint256 allowance = ith.allowance(msg.sender, address(this));
        if (ith.balanceOf(msg.sender) < amount) revert Liquidator__Not_Enough_Ithil();
        if (allowance < amount) revert Liquidator__Not_Enough_Ithil_Allowance(allowance);
        stakes[msg.sender] += amount;
        ith.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        IERC20 ith = IERC20(ithil);
        uint256 staked = stakes[msg.sender];
        if (staked < amount) revert Liquidator__Unstaking_Too_Much(staked);
        stakes[msg.sender] -= amount;
        ith.safeTransfer(msg.sender, amount);
    }

    function liquidateSingle(address _strategy, uint256 positionId) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        uint256 penalty = computePenalty();
        strategy.forcefullyClose(positionId, msg.sender, penalty);
    }

    function marginCall(
        address _strategy,
        uint256 positionId,
        uint256 extraMargin
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        uint256 penalty = computePenalty();
        strategy.modifyCollateralAndOwner(positionId, extraMargin, msg.sender, penalty);
    }

    function purchaseAssets(
        address _strategy,
        uint256 positionId,
        uint256 price
    ) external {
        //todo: add checks on liquidator
        IStrategy strategy = IStrategy(_strategy);
        uint256 penalty = computePenalty();
        strategy.forcefullyDelete(positionId, price, msg.sender, penalty);
    }

    function computePenalty() public view returns (uint256) {
        if (maximumStake > 0)
            return
                uint256(VaultMath.RESOLUTION).positiveSub((stakes[msg.sender] * VaultMath.RESOLUTION) / maximumStake);
        else return 0;
    }
}
