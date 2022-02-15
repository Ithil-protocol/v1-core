// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { MockToken } from "./MockToken.sol";

contract MockTaxedToken is MockToken {
    uint256 public taxFee;

    constructor(
        string memory name,
        string memory symbol,
        address to
    ) MockToken(name, symbol, to) {}

    function _partialBurn(address from, uint256 amount) internal returns (uint256) {
        uint256 toBurn = (amount * taxFee) / 100;
        super._burn(from, toBurn);
        amount = amount - toBurn;

        return amount;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, _partialBurn(msg.sender, amount));
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        return super.transferFrom(from, to, _partialBurn(from, amount));
    }

    function setTax(uint256 tax) external onlyOwner {
        taxFee = tax;
    }
}
