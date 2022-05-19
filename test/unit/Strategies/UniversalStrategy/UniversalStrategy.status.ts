import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../../common/params";

export function checkStatus(): void {
  it("UniversalStrategy: status", async function () {
    const token = this.mockWETH;
    const quote = await this.universalStrategy.quote(token.address, token.address, amount);
    expect(quote[0]).to.equal(amount);
    expect(quote[1]).to.equal(amount);

    expect(await this.universalStrategy.name()).to.equal("UniversalStrategy");
  });
}
