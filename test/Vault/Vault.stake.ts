import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function checkStake(): void {
  it("Vault: stake", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH;
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);

    await token.mintTo(investor.address, amount.mul(2));
    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee);

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
    const token = this.mockWETH;
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const amountBack = ethers.utils.parseUnits("5.0", 17);

    await token.mintTo(investor.address, amount.mul(2));
    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee);

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
