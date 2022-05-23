import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

import {
  marginTokenLiquidity,
  marginTokenMargin,
  leverage,
  baseFee,
  fixedFee,
  minimumMargin,
} from "../../common/params";

export function checkStaking(): void {
  it("Vault: stake", async function () {
    const token = this.token;
    const investor = this.signers.investor;
    const amount = this.tokensAmount;

    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee, minimumMargin);

    const initialState = {
      balance: await token.balanceOf(investor.address),
    };

    const rsp = await this.vault.connect(investor).stake(token.address, amount);
    const events = (await rsp.wait()).events;

    const finalState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(finalState.balance).to.equal(initialState.balance.sub(amount));

    const validEvents = events?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validEvents?.length).equal(1);
  });

  it("Vault: unstake", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.token;
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const amountBack = ethers.utils.parseUnits("5.0", 17);

    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee, amount);

    const initialState = {
      balance: await token.balanceOf(investor.address),
    };

    await this.vault.connect(investor).stake(token.address, amount);
    const rsp = await this.vault.connect(investor).unstake(token.address, amountBack);
    const events = (await rsp.wait()).events;

    const finalState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(finalState.balance).to.equal(initialState.balance.sub(amount).add(amountBack));

    const validEvents = events?.filter(
      event => event.event === "Withdrawal" && event.args && event.args[0] === investor.address,
    );
    expect(validEvents?.length).equal(1);
  });
}

export function checkWhitelist(): void {
  it("Vault: whitelistTokenAndExec", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const OUSD = "0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86";
    let ABI = '[{"inputs": [],"name": "rebaseOptIn","outputs": [],"stateMutability": "nonpayable","type": "function"}]';
    let iface = new ethers.utils.Interface(ABI);
    const data = iface.encodeFunctionData("rebaseOptIn");

    const initialState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    await this.vault.whitelistTokenAndExec(OUSD, baseFee, fixedFee, ethers.utils.parseEther("100000"), data);

    const finalState = {
      vaultState: await this.vault.vaults(OUSD),
    };

    expect(initialState.vaultState.supported).to.equal(false);
    expect(finalState.vaultState.supported).to.equal(true);
    expect(finalState.vaultState.baseFee).to.equal(BigNumber.from(baseFee));
    expect(finalState.vaultState.fixedFee).to.equal(BigNumber.from(fixedFee));
  });
}
