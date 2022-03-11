import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../common/constants";

export function checkQuote(): void {
  it("UniversalStrategy: quote", async function () {
    const token = this.mockWETH;
    const quote = await this.universalStrategy.quote(token.address, token.address, amount);
    console.log(quote);
  });
}
