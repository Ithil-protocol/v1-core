import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { INITIAL_VAULT_STATE, compareVaultStates } from "../../common/utils";

export function checkWhiteList(): void {
  it("Vault: whitelistToken", async function () {
    const token = this.mockWETH.address;
    const initialState = await this.vault.vaults(token);

    // First, initial state is blank
    compareVaultStates(initialState, INITIAL_VAULT_STATE);

    // Whitelist
    const baseFee = 10;
    const fixedFee = 11;
    await this.vault.whitelistToken(token, baseFee, fixedFee);

    const finalState = await this.vault.vaults(token);

    const expectedState = {
      supported: true,
      locked: false,
      wrappedToken: finalState.wrappedToken,
      creationTime: finalState.creationTime,
      baseFee: BigNumber.from(baseFee),
      fixedFee: BigNumber.from(fixedFee),
      netLoans: BigNumber.from(0),
      insuranceReserveBalance: BigNumber.from(0),
      optimalRatio: BigNumber.from(0),
      treasuryLiquidity: BigNumber.from(0),
    };

    // Final state as expected
    compareVaultStates(finalState, expectedState);
  });
}
