import { isCommunityResourcable } from "@ethersproject/providers";
import { expect } from "chai";
import { ethers } from "hardhat";

export function checkStaking(): void {
  it("Vault: stake and unstake tokens", async function () {
    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH;
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const amountBack = ethers.utils.parseUnits("1.0", 18);

    await token.mintTo(investor.address, amount.mul(2));
    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee);

    const initialState = {
      balance: await token.balanceOf(investor.address),
    };

    const stakeTx = await this.vault.connect(investor).stake(token.address, amount);
    const stakeEvents = (await stakeTx.wait()).events;

    const middleState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(middleState.balance).to.equal(initialState.balance.sub(amount));

    const validStakeEvents = stakeEvents?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validStakeEvents?.length).equal(1);

    const unstakeTx = await this.vault.connect(investor).unstake(token.address, amountBack);
    const unstakeEvents = (await unstakeTx.wait()).events;

    const finalState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(finalState.balance).to.equal(initialState.balance.sub(amount).add(amountBack));

    const validUnstakeEvents = unstakeEvents?.filter(
      event => event.event === "Withdrawal" && event.args && event.args[0] === investor.address,
    );
    expect(validUnstakeEvents?.length).equal(1);
  });

  it("Vault: stake and unstake ETH", async function () {
    const provider = ethers.getDefaultProvider();

    const baseFee = 10;
    const fixedFee = 11;
    const token = this.mockWETH;
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const amountBack = ethers.utils.parseUnits("1.0", 18);

    await token.connect(investor).approve(this.vault.address, amount);
    await this.vault.whitelistToken(token.address, baseFee, fixedFee);

    const initialState = {
      balance: await provider.getBalance(investor.address),
    };

    const stakeTx = await this.vault.connect(investor).stakeETH(amount, { value: amount });
    const stakeEvents = await stakeTx.wait();

    const middleState = {
      balance: await provider.getBalance(investor.address),
    };

    console.log("middleState.balance", middleState.balance.toString());
    console.log("initialState.balance", initialState.balance.toString());
    console.log("stakeEvents.gasUsed", stakeEvents.gasUsed.toString());

    expect(middleState.balance).to.equal(initialState.balance.sub(amount).sub(stakeEvents.gasUsed));

    const validStakeEvents = stakeEvents.events?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validStakeEvents?.length).equal(1);

    const unstakeTx = await this.vault.connect(investor).unstakeETH(amountBack);
    const unstakeEvents = await unstakeTx.wait();

    const finalState = {
      balance: await provider.getBalance(investor.address),
    };

    expect(finalState.balance.add(unstakeEvents.gasUsed).add(stakeEvents.gasUsed)).to.equal(
      initialState.balance.sub(amount).add(amountBack),
    );

    const validUnstakeEvents = unstakeEvents.events?.filter(
      event => event.event === "Withdrawal" && event.args && event.args[0] === investor.address,
    );
    expect(validUnstakeEvents?.length).equal(1);
  });
}
