// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { MockToken } from "./MockToken.sol";
import "hardhat/console.sol";

contract MockWETH is MockToken {
    constructor() MockToken("Wrapped Ether", "WETH", 18) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        require(address(this).balance >= wad, "WETH: internal balance error");
        require(balanceOf(msg.sender) >= wad, "WETH: sender balance error");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
