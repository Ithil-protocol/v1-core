// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    mapping(address => uint256) private throttledMinters;
    mapping(address => bool) private blockedMinters;
    uint256 private throttlingPeriod = 0;
    uint8 private immutable decimalPlaces;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) {
        decimalPlaces = _decimals;
    }

    function toggleBlock(address account) external onlyOwner {
        blockedMinters[account] = !blockedMinters[account];
    }

    function setThrottlingPeriod(uint256 period) external onlyOwner {
        throttlingPeriod = period;
    }

    function mintTo(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function mint() external {
        address to = msg.sender;
        require(!blockedMinters[to], "MockToken: Blocked account");
        require(block.timestamp - throttledMinters[to] >= throttlingPeriod, "MockToken: Too many requests");
        _mint(to, 1000 * 10**decimals());
        throttledMinters[to] = block.timestamp;
    }

    function decimals() public view override returns (uint8) {
        return decimalPlaces;
    }
}
