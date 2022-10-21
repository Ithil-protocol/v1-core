// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { TokenizedVault } from "../TokenizedVault.sol";

contract MockTimeTokenizedVault is TokenizedVault {
    uint256 public time;

    constructor(address _token) TokenizedVault(_token) {
        // Monday, October 5, 2020 9:00:00 AM GMT-05:00
        time = 1601906400;
    }

    function advanceTime(uint256 by) external {
        time += by;
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }
}
