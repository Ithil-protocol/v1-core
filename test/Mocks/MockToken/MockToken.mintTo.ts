import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkMintTo(): void {
  it("MockToken: mintTo", async function () {
    const user = this.signers.trader;
    await this.mockToken.mintTo(user.address, amount);
    const balance = await this.mockToken.balanceOf(user.address);
    expect(balance).to.eq(amount);
  });
}
