// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IConnextHandler } from "../interfaces/external/IConnextHandler.sol";

/// @title    BridgeHelper library
/// @author   Ithil
/// @notice   A library to perform simple token bridging
library BridgeHelper {
    function getDomain(uint256 chainId) internal pure returns (uint32) {
        // @todo TBD
        if (chainId == 5) return 1735353714;
        else if (chainId == 420) return 1735356532;
        else revert(); // will never happen as 
    }

    function bridgedTransfer(
        IERC20 asset,
        address connext,
        address to,
        uint256 amount,
        uint256 minAmount,
        uint32 destinationDomain
    ) internal {
        uint32 originDomain = getDomain(block.chainid);

        IConnextHandler.CallParams memory callParams = IConnextHandler.CallParams({
            to: to,
            callData: "", // empty here because we're only sending funds
            originDomain: originDomain,
            destinationDomain: destinationDomain,
            agent: msg.sender, // address allowed to execute transaction on destination side in addition to relayers
            recovery: msg.sender, // fallback address to send funds to if execution fails on destination side
            forceSlow: false, // option to force slow path instead of paying 0.05% fee on fast path transfers
            receiveLocal: false, // option to receive the local bridge-flavored asset instead of the adopted asset
            callback: address(0), // zero address because we don't expect a callback
            callbackFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            relayerFee: 0, // fee paid to relayers; relayers don't take any fees on testnet
            destinationMinOut: minAmount // the minimum amount that the user will accept inclding slippage
        });

        IConnextHandler.XCallArgs memory xcallArgs = IConnextHandler.XCallArgs({
            params: callParams,
            transactingAsset: address(asset),
            transactingAmount: amount,
            originMinOut: minAmount
        });

        IConnextHandler(connext).xcall(xcallArgs);
    }
}
