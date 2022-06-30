// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IVault } from "../interfaces/IVault.sol";
import { IStrategy } from "../interfaces/IStrategy.sol";

/// @title    AbstractStrategy contract
/// @author   Ithil
/// @notice   Abstract contract which represent the core of the strategies
abstract contract AbstractStrategy is ERC721, IStrategy, Ownable {
    IVault public immutable vault;
    mapping(uint256 => Position) public positions;

    constructor(
        address _vault,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        vault = IVault(_vault);
    }

    function _openPosition(Order memory order) internal virtual returns (uint256);

    function _closePosition(Position memory position, uint256 expectedCost)
        internal
        virtual
        returns (uint256 amountIn, uint256 amountOut);

    function quote(
        address src,
        address dst,
        uint256 amount
    ) public view virtual override returns (uint256, uint256);

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId));
        return ""; /// @todo generate SVG on-chain
    }
}
