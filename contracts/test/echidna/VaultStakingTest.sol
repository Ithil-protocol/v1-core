// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { VaultEnvironmentSetup } from "./VaultEnvironmentSetup.sol";
import { VaultState } from "../../libraries/VaultState.sol";

/// @dev Used for testing, unaudited
contract VaultStakingTest is VaultEnvironmentSetup {
    address public immutable user;

    constructor() {
        user = msg.sender;
    }

    function boost(address token, uint256 amount) public {
        vault.boost(token, amount);
    }

    function unboost(address token, uint256 amount) public {
        vault.unboost(token, amount);
    }

    function stake(address token, uint256 amount) public {
        vault.stake(token, amount);
    }

    function unstake(address token, uint256 amount) public {
        vault.unstake(token, amount);
    }

    function stakeETH() public payable {
        uint256 amount = msg.value;
        vault.stakeETH(amount);
    }

    function unstakeETH(uint256 amount) public {
        vault.unstakeETH(amount);
    }

    function toggleLock(bool locked, address token) public {
        vault.toggleLock(locked, token);
    }

    function echidna_check_staking_weth() public view returns (bool) {
        return true;
    }
}
