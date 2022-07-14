// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IWETH } from "../interfaces/external/IWETH.sol";
import { MockToken } from "./MockToken.sol";

/// @dev Used for testing, unaudited
contract MockWETH is MockToken, IWETH {
    // solhint-disable-next-line no-empty-blocks
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
