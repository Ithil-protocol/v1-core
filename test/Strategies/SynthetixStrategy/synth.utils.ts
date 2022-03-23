import { utils } from "ethers";

const strToBytes = (text: string, length = text.length) => {
  if (text.length > length) {
    throw new Error(`Cannot convert String of ${text.length} to bytes${length} (it's too big)`);
  }
  // extrapolated from https://github.com/ethers-io/ethers.js/issues/66#issuecomment-344347642
  let result = utils.hexlify(utils.toUtf8Bytes(text));
  while (result.length < 2 + length * 2) {
    result += "0";
  }
  return utils.arrayify(result);
};

/**
 * converts a string to a bytes32 array (right padding for Solidity)
 * @param text {String}
 */
export function toUtf8Bytes32(text: string) {
  return strToBytes(text, 32);
}
