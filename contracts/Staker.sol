// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { VaultMath } from "./libraries/VaultMath.sol";
import { IStaker } from "./interfaces/IStaker.sol";

contract Staker is ERC20, ERC20Permit, ERC20Votes, Ownable, IStaker {
    using SafeERC20 for IERC20;

    IERC20 public immutable override token;
    uint256 public maximumStake;

    event MaxStakeWasChanged(uint256 maxStake);

    error Non_Transferrable();

    constructor(address _token)
        ERC20(
            string(abi.encodePacked("Staked ", IERC20Metadata(address(_token)).name())),
            string(abi.encodePacked("s", IERC20Metadata(address(_token)).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("Staked ", IERC20Metadata(address(_token)).name())))
    {
        token = IERC20(_token);
        maximumStake = type(uint256).max;
    }

    function setMaximumStake(uint256 amount) external onlyOwner {
        maximumStake = amount;

        emit MaxStakeWasChanged(amount);
    }

    // It is computed as of the tokens staked
    function rewardPercentage() public view override returns (uint256) {
        if (maximumStake > 0) {
            uint256 stakePercentage = (balanceOf(msg.sender) * VaultMath.RESOLUTION) / maximumStake;
            if (stakePercentage > VaultMath.RESOLUTION) return VaultMath.RESOLUTION;
            else return stakePercentage;
        } else {
            return 0;
        }
    }

    function stake(uint256 amount) external override {
        _mint(msg.sender, amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external override {
        assert(balanceOf(msg.sender) < amount);

        _burn(msg.sender, amount);
        token.safeTransfer(msg.sender, amount);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // non-transferrable or burnable token
        if (from != address(0)) revert Non_Transferrable();

        super._afterTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
