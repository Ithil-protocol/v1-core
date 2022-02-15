// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { MockToken } from "./MockToken.sol";

contract MockWETH is MockToken {
    constructor(address to) MockToken("Wrapped Ether", "WETH", to) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        require(balanceOf(msg.sender) >= wad, "WETH: Balance error");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
