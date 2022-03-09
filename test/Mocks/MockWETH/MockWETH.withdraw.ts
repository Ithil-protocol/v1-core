import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkWithdraw(): void {
  it("MockWETH: withdraw", async function () {
    const user = this.signers.trader;
    await this.mockWETH.mintTo(user.address, amount);
    const balanceBefore = await this.mockWETH.balanceOf(user.address);
    await this.mockWETH.connect(user).withdraw(amount);
    const balanceAfter = await this.mockWETH.balanceOf(user.address);
    console.log({ balanceBefore, balanceAfter });
  });
}
