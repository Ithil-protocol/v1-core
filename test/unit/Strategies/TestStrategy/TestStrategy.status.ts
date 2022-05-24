import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../../common/params";

export function checkStatus(): void {
  it("TestStrategy: status", async function () {
    const token = this.mockWETH;
    const quote = await this.TestStrategy.quote(token.address, token.address, amount);
    expect(quote[0]).to.equal(amount);
    expect(quote[1]).to.equal(amount);

    expect(await this.TestStrategy.name()).to.equal("TestStrategy");
  });
}
