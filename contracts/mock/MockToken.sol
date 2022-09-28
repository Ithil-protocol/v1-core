// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Used for testing, unaudited
contract MockToken is ERC20Permit, Ownable {
    mapping(address => uint256) private throttledMinters;
    mapping(address => bool) private blockedMinters;
    uint256 private throttlingPeriod = 0;
    uint8 private immutable decimalPlaces;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
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
