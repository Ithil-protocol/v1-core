// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IAddressResolver } from "synthetix/contracts/interfaces/IAddressResolver.sol";
import { IKyberNetworkProxy } from "../../interfaces/IKyberNetworkProxy.sol";
import { MockExchangeRates } from "./MockExchangeRates.sol";
import { MockSynthetix } from "./MockSynthetix.sol";

contract MockAddressResolver is IAddressResolver {
    IKyberNetworkProxy kyber;
    MockSynthetix synthetix;
    MockExchangeRates exchangeRates;

    constructor(address _kyber, address _baseToken) {
        kyber = IKyberNetworkProxy(_kyber);
        synthetix = new MockSynthetix(_kyber);
        exchangeRates = new MockExchangeRates(_kyber, _baseToken);
    }

    function registerToken(bytes32 name, address token) public {
        synthetix.registerToken(name, token);
        exchangeRates.registerToken(name, token);
    }

    function getAddress(bytes32 name) external view override returns (address) {
        if (name == bytes32("Synthetix")) return address(synthetix);
        if (name == bytes32("ExchangeRates")) return address(exchangeRates);
        return address(0);
    }

    function getSynth(bytes32 key) external view override returns (address) {
        return address(0);
    }

    function requireAndGetAddress(bytes32 name, string calldata reason) external view override returns (address) {
        return address(0);
    }
}
