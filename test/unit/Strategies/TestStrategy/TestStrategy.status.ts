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
    expect(await this.TestStrategy.symbol()).to.equal("ITHIL-TS-POS");
    expect(this.TestStrategy.balanceOf(this.signers.admin.address)).to.equal(0);

    await this.TestStrategy.transferFrom(this.signers.admin.address, this.signers.investor.address, 0);

    expect(this.TestStrategy.balanceOf(this.signers.admin.address)).to.equal(0);
    expect(this.TestStrategy.balanceOf(this.signers.investor.address)).to.equal(1);
  });
}
