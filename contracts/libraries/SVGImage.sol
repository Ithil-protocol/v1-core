// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.12;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title    SVGImage library
/// @author   Ithil
/// @notice   A library to create a SVG image on-chain
library SVGImage {
    /* eslint-disable quotes, max-line-length */
    function generateMetadata(
        string memory name,
        string memory symbol,
        uint256 id,
        address owner,
        uint256 createdAt
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            symbol,
                            '", "description":"',
                            name,
                            '", "image":"data:image/svg+xml;base64,',
                            _getSVGImageBase64Encoded(name, id),
                            '","attributes":[{"trait_type":"positionId","value":"',
                            Strings.toString(id),
                            '"},{"trait_type":"owner","value":"',
                            Strings.toHexString(owner),
                            '"},{"trait_type":"createdAt","value":"',
                            Strings.toString(createdAt),
                            '"}]}'
                        )
                    )
                )
            );
    }

    function _getSVGImageBase64Encoded(string memory strategyName, uint256 id) internal pure returns (string memory) {
        return
            Base64.encode(
                abi.encodePacked(
                    "<?xml version='1.0' encoding='utf-8'?><svg version='1.1' id='Ebene_1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' viewBox='0 0 500 500' style='enable-background:new 0 0 500 500;' xml:space='preserve'><rect fill='#121E35' width='500' height='500'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M345.9,222.3c0,0,25.7,14.4,52.3,9.3c0,0-4,6.4-9.8,9.1'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M337.1,271.1c67.6-7.6,79.9-21.2,81.9-22.5'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M72.8,260.3c0,0,12.5,8.4,92.7,12.9'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M331.5,262.7c3.3,5.9,8.1,12.3,15,18.7c-9.7,1.2-21.2-1.4-21.2-1.4s3.4,33.3,27.2,62.2c-18.5,3.6-41.9-14.5-41.9-14.5l2.8,73.7c0,0-15.3-3.9-30.1-25.5c-3,32.1-27.1,58.3-27.1,58.3s-26.1-24.3-31.5-56.1c-9.7,18.1-27.5,27.4-28,27.7c0,0-2.8-73.7-2.8-73.7s-13.6,15.3-39.5,16.7c19.7-25.6,22.2-52.2,22.2-60.1c-5.4,0.7-13.1,2-21.9,0.8c12.8-15.8,21-33.6,23.2-43.2'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M197.6,248.1l0.9,22.7c0.2,4.6,2.5,8.8,6.2,11.4l0.6,0.4c4.2,2.9,6.7,7.6,6.8,12.7l0.1,7.4l5.3-13c2.8-7.8,10.1-13.1,18.3-13.4l28.8-1.1c8.3-0.3,15.9,4.4,19.3,12l6.4,14.3l-0.3-9.6c-0.1-4.2,1.6-8.3,4.7-11.1l2.4-2.3c3-2.7,4.6-6.6,4.4-10.7l-0.2-6.2'/><path fill='#E0FFFF' stroke='#E0FFFF' stroke-width='7' stroke-miterlimit='10' d='M211.1,250.5c0.5,1.4,2.8,5.1,6.3,7.2c4.4,2.7,8.2,1.5,10.6,0.6c2.7-1.1,4.7-3.2,5.4-4.8L211.1,250.5z'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M197.4,247.5c-79.1-6.3-125.1,11.3-128.4,12.6l61.1-26.5c16.8-7.3,31.8-16.4,43.2-28.2c11-11.2,18.7-24.9,21.6-41.5c0.4-2.2,0.7-4.4,0.9-6.7c3.4-36.8,1.8-65.6-42.1-103.5c74.7-3.1,113.3,34.6,137.2,80.6c6.4,12.2,11.7,25,16.4,37.7c2.3,6.2,5.2,12.3,8.8,18.1c13.2,21.6,34.5,39.5,60.3,47c32.7,9.5,42.7,11.6,42.7,11.6s-55.3,28.1-169.5,6.1C230.8,251.1,213.4,248.8,197.4,247.5'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M267.1,308.9c-3.9,1.7-9.8,3.7-16,3.7c-6.1,0-11-1.8-14.1-3.3'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M284,287.2c-3.4-7.6-11-12.3-19.3-12l-14.4,0.6l-14.4,0.6c-8.3,0.3-15.5,5.6-18.3,13.4l-11.4,32.8c0.2,0,24.5-1,44.8-27.8c22.3,25.2,46.7,24.3,46.8,24.3L284,287.2z'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M316,190.1c-71.4-28.7-142.7,15.4-142.7,15.4c11-11.2,18.7-24.9,21.6-41.5c31.5-29.7,90.4-23.4,102.8-15.6c3.5,7.8,6.6,15.7,9.5,23.5C309.5,178.2,312.4,184.2,316,190.1z'/><path fill='none' stroke='#93BADD' stroke-width='7' stroke-miterlimit='10' d='M263.3,162.3c0,7.9-6.2,14.7-14.1,14.7c-2,0-4-0.3-5.9-1.5c4-2,6.8-6.1,6.8-11c0-6.5-4.9-11.9-11.4-12.1c2.5-3.6,6.2-4.4,10.3-4.4C256.9,148,263.3,154.4,263.3,162.3z'/>  <text x='20' y='480' class='small' font-size='10px' font-family='sans-serif' fill='#E0FFFF'>#",
                    Strings.toString(id),
                    " - ",
                    strategyName,
                    "</text></svg>"
                )
            );
    }
    /* eslint-enable quotes, max-line-length */
}
