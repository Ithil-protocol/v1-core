// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;
pragma experimental ABIEncoderV2;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IWrappedToken } from "./interfaces/IWrappedToken.sol";

/// @title    WrappedToken contract
/// @author   Ithil
/// @notice   Uses ERC20 Permit OpenZeppelin library
contract WrappedToken is IWrappedToken, ERC20Permit, Ownable {
    IERC20Metadata public immutable nativeToken;

    /// @param _token The base native token
    constructor(address _token)
        ERC20(
            string(abi.encodePacked("Ithil ", IERC20Metadata(address(_token)).name())),
            string(abi.encodePacked("i", IERC20Metadata(address(_token)).symbol()))
        )
        ERC20Permit(string(abi.encodePacked("Ithil ", IERC20Metadata(address(_token)).name())))
    {
        nativeToken = IERC20Metadata(_token);
    }

    /// @inheritdoc IWrappedToken
    function decimals() public view override(ERC20, IWrappedToken) returns (uint8) {
        return nativeToken.decimals();
    }

    /// @inheritdoc IWrappedToken
    function mint(address user, uint256 amount) external override onlyOwner {
        super._mint(user, amount);
    }

    /// @inheritdoc IWrappedToken
    function burn(address user, uint256 amount) external override onlyOwner {
        super._burn(user, amount);
    }
}
