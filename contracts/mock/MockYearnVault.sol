// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IYearnVault } from "../interfaces/IYearnVault.sol";

contract MockYearnVault is IYearnVault, ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable nativeToken;
    address public immutable registry;

    constructor(address token)
        ERC20(
            string(abi.encodePacked("Yearn ", IERC20Metadata(address(token)).name())),
            string(abi.encodePacked("y", IERC20Metadata(address(token)).symbol()))
        )
    {
        nativeToken = IERC20(token);
        registry = msg.sender;
    }

    function deposit(uint256 amount, address recipient) external override returns (uint256) {
        require(nativeToken.balanceOf(recipient) >= amount, "MockYearnVault: not enough tokens");
        require(nativeToken.allowance(recipient, address(this)) >= amount, "MockYearnVault: allowance error");

        nativeToken.safeTransferFrom(recipient, address(this), amount);
        uint256 shares = amount / _pricePerShare();
        _mint(recipient, shares);

        return shares;
    }

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss
    ) external override returns (uint256) {
        require(maxShares >= balanceOf(recipient), "MockYearnVault: not enough shares");

        _burn(recipient, maxShares);
        uint256 assets = maxShares * _pricePerShare();
        require(assets >= maxShares * maxLoss, "MockYearnVault: max loss constraint fails");

        nativeToken.safeTransfer(recipient, assets);

        return assets;
    }

    function pricePerShare() external view override returns (uint256) {
        return _pricePerShare();
    }

    function _pricePerShare() internal view returns (uint256) {
        (bool success, bytes memory data) = registry.staticcall(abi.encodeWithSignature("priceForShare()"));
        require(success, "MockYearnVault: static call error");

        return abi.decode(data, (uint256));
    }
}
