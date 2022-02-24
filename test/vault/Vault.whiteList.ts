import { expect } from "chai";
import { BigNumber, ethers } from "ethers";

export function checkWhiteList(): void {
  it("check whitelistToken", async function () {
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
    console.log(initialState, finalState);

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });

  it("check whitelistTokenAndExec", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const OUSD = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    let ABI = '[{"inputs": [],"name": "rebaseOptIn","outputs": [],"stateMutability": "nonpayable","type": "function"}]';
    let iface = new ethers.utils.Interface(ABI);
    const data = iface.encodeFunctionData("rebaseOptIn");

    const initialState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    await this.vault.whitelistTokenAndExec(OUSD, baseFee, fixedFee, data);

    const finalState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });
}
