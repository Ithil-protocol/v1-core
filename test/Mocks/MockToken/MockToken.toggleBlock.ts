import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkToggleBlock(): void {
  it("MockToken: toggleBlock", async function () {
    const user = this.signers.trader;
    await this.mockToken.toggleBlock(user.address);
    // await this.mockToken.connect(user).mint(); // TODO: this should be failed
  });
}
