// SPDX-License-Identifier: BUSL-1.1

pragma solidity >=0.8.10;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VoteLibrary.sol";

/// @title    Treasury contract
/// @author   Ithil
/// @notice   Responsible for APY boosts and governance decisions
contract DAO {
    using SafeERC20 for IERC20;
    using VoteLibrary for VoteLibrary.VoteData;

    error DAO__Vote_Not_Started(uint256 id);
    error DAO__Vote_Finished(uint256 id);
    error DAO__Vote_Locked(uint256 id);
    error DAO__Quorum_Not_Met(uint256 score);

    IERC20 public immutable governanceToken;

    mapping(uint256 => VoteLibrary.VoteData) public votedData;
    uint256 public voteId;
    uint256 public quorum;
    address public treasury;

    constructor(
        address _treasury,
        address _governanceToken,
        uint256 _quorum
    ) {
        treasury = _treasury;
        governanceToken = IERC20(_governanceToken);
        quorum = _quorum;
    }

    function launchVote(bytes calldata data) external {
        voteId++;
        VoteLibrary.VoteData storage vote = votedData[voteId];
        vote.launch(data);
    }

    function stakeToVote(uint256 id, uint256 amount) external {
        VoteLibrary.VoteData storage vote = votedData[id];
        uint256 currentTime = block.timestamp;

        (uint256 start, uint256 finish, ) = vote.voteSchedule();

        if (currentTime < start) revert DAO__Vote_Not_Started(id);
        if (currentTime > finish) revert DAO__Vote_Finished(id);

        vote.stakeAndUpdateScore(governanceToken, amount, currentTime);
    }

    function executeVote(uint256 id) external {
        VoteLibrary.VoteData memory vote = votedData[id];
        uint256 score = vote.score;
        bytes memory data = vote.votedData;

        (, , uint256 unlock) = vote.voteSchedule();

        if (block.timestamp < unlock) revert DAO__Vote_Locked(id);

        if (score < quorum) revert DAO__Quorum_Not_Met(score);

        (bool success, ) = treasury.call(data);

        require(success, "Vote execution failed");
    }
}
