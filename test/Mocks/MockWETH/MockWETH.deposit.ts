import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkDeposit(): void {
  it("MockWETH: deposit", async function () {
    const user = this.signers.trader;
    const balanceBefore = await this.mockWETH.balanceOf(user.address);
    await this.mockWETH.connect(user).deposit(); // TODO: should pass amount as msg.value
    const balanceAfter = await this.mockWETH.balanceOf(user.address);
    console.log({ balanceBefore, balanceAfter });
  });
}
