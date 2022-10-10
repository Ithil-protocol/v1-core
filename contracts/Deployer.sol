// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CREATE3 } from "solmate/src/utils/CREATE3.sol";
import { Vault } from "./Vault.sol";
import { Staker } from "./Staker.sol";
import { Liquidator } from "./Liquidator.sol";

/// @title    Deployer contract
/// @author   Ithil
/// @notice   Used to deploy Ithil smart contracts to deterministic addresses
///           on multiple chains irrespective of contracts' bytecode
contract Deployer is Ownable {
    bytes32 internal constant salt = keccak256(bytes("ithil"));

    function getDeployed() public view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}

contract VaultDeployer is Deployer {
    address public vault;

    function deploy(address weth) external onlyOwner {
        vault = CREATE3.deploy(salt, abi.encodePacked(type(Vault).creationCode, abi.encode(weth)), 0);
    }
}

contract StakerDeployer is Deployer {
    address public staker;

    function deploy(address token) external onlyOwner {
        staker = CREATE3.deploy(salt, abi.encodePacked(type(Staker).creationCode, abi.encode(token)), 0);
    }
}

contract LiquidatorDeployer is Deployer {
    address public liquidator;

    function deploy(address staker) external onlyOwner {
        liquidator = CREATE3.deploy(salt, abi.encodePacked(type(Liquidator).creationCode, abi.encode(staker)), 0);
    }
}
