// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title    GeneralMath library
/// @author   Ithil
/// @notice   A library to perform the most common operations
library VoteLibrary {
    using SafeERC20 for IERC20;

    struct VoteData {
        bytes votedData;
        uint256 score;
        uint256 stakes;
        uint256 lastStake;
        uint256 createdAt;
    }

    function launch(VoteData storage self, bytes calldata data) internal {
        self.votedData = data;
        self.createdAt = block.timestamp;
    }

    function stakeAndUpdateScore(
        VoteData storage self,
        IERC20 governanceToken,
        uint256 amount,
        uint256 currentTime
    ) internal {
        self.score += self.stakes * (currentTime - self.lastStake);
        self.lastStake = currentTime;
        self.stakes += amount;

        IERC20 govToken = IERC20(governanceToken);
        govToken.transferFrom(msg.sender, address(this), amount);
    }

    function voteSchedule(VoteData memory vote)
        internal
        pure
        returns (
            uint256 start,
            uint256 finish,
            uint256 unlock
        )
    {
        start = vote.createdAt + 86400; // Vote starts 1 day after creation
        finish = start + 432000; // 5 days time to complete the vote
        unlock = finish + 86400; // Tokens can be unstaked 1 day after finish
    }
}
