import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkWhiteList(): void {
  it("Vault: whitelistToken", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH.address;
    const initialState = {
      vaultState: await this.vault.vaults(token),
    };

    await this.vault.whitelistToken(token, baseFee, fixedFee);

    const finalState = {
      vaultState: await this.vault.vaults(token),
    };

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });
}
