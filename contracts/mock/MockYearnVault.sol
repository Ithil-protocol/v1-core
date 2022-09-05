// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IYearnVault } from "../interfaces/external/IYearnVault.sol";

/// @dev Used for testing, unaudited
contract MockYearnVault is IYearnVault, ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable nativeToken;
    address public immutable registry;

    constructor(address vaultToken)
        ERC20(
            string(abi.encodePacked("Yearn ", IERC20Metadata(address(vaultToken)).name())),
            string(abi.encodePacked("y", IERC20Metadata(address(vaultToken)).symbol()))
        )
    {
        nativeToken = IERC20(vaultToken);
        registry = msg.sender;
    }

    function token() external view override returns (address) {
        return address(nativeToken);
    }

    function deposit(uint256 amount, address recipient) external override returns (uint256) {
        require(nativeToken.balanceOf(msg.sender) >= amount, "MockYearnVault: not enough tokens");
        require(nativeToken.allowance(msg.sender, address(this)) >= amount, "MockYearnVault: allowance error");
        nativeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 unitAmount = 10**IERC20Metadata(address(nativeToken)).decimals();
        uint256 shares = (amount * unitAmount) / _pricePerShare();
        _mint(recipient, shares);
        return shares;
    }

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss
    ) external override returns (uint256) {
        require(maxShares <= balanceOf(msg.sender), "MockYearnVault: not enough shares");
        _burn(msg.sender, maxShares);
        uint256 unitAmount = 10**IERC20Metadata(address(nativeToken)).decimals();
        uint256 assets = (maxShares * _pricePerShare()) / unitAmount;
        require(assets >= (maxShares * (10000 - maxLoss)) / 10000, "MockYearnVault: max loss constraint fails");

        nativeToken.safeTransfer(recipient, assets);

        return assets;
    }

    function pricePerShare() external view override returns (uint256) {
        return _pricePerShare();
    }

    function _pricePerShare() internal view returns (uint256) {
        (bool success, bytes memory data) = registry.staticcall(
            abi.encodeWithSignature("pricePerShare(address)", address(nativeToken))
        );
        require(success, "MockYearnVault: static call error");

        return abi.decode(data, (uint256));
    }
}
