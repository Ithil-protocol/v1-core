import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { amount } from "../../constants";

export function checkWithdraw(): void {
  it("MockYearnVault: withdraw", async function () {
    const token = this.mockWETH;
    const user = this.signers.trader;

    await token.mintTo(user.address, amount);
    await token.connect(user).approve(this.mockYearnVault.address, amount);
    await this.mockYearnVault.deposit(amount, user.address);

    await this.mockYearnVault.withdraw(amount, user.address, amount);
  });
}
