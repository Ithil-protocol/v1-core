// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { TokenisedVault } from "../TokenisedVault.sol";

contract MockTokenisedVault is TokenisedVault {
    uint256 public time;

    constructor(IERC20Metadata _token) TokenisedVault(_token) {
        // Monday, October 5, 2020 9:00:00 AM GMT-05:00
        time = 1601906400;
    }

    function advanceTime(uint256 by) external {
        time += by;
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }

    function setAccounting(
        uint256 _netLoans,
        uint256 _latestRepay,
        int256 _currentProfits
    ) external {
        netLoans = _netLoans;
        latestRepay = _latestRepay;
        currentProfits = _currentProfits;
    }
}
