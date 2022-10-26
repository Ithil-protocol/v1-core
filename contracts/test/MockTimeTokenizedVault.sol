// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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

    function setAccounting(
        uint256 netLoans,
        uint256 latestRepay,
        int256 currentProfits
    ) external {
        vaultAccounting.netLoans = netLoans;
        vaultAccounting.latestRepay = latestRepay;
        vaultAccounting.currentProfits = currentProfits;
    }

    function burnNatives(uint256 amount) external {
        IERC20(asset()).transfer(address(0), amount);
    }

    function burnWrapped(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
