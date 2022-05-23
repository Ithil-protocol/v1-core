import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { INITIAL_VAULT_STATE, compareVaultStates } from "../../common/utils";
import { baseFee, fixedFee, minimumMargin } from "../../common/params";

export function checkWhiteList(): void {
  it("Vault: whitelistToken", async function () {
    const token = this.mockWETH.address;
    const initialState = await this.vault.vaults(token);

    // First, initial state is blank
    compareVaultStates(initialState, INITIAL_VAULT_STATE);

    // Whitelist
    await this.vault.whitelistToken(token, baseFee, fixedFee, minimumMargin);

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
    };

    // Final state as expected
    compareVaultStates(finalState, expectedState);
  });
}
