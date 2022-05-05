import { isCommunityResourcable } from "@ethersproject/providers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";

export function checkStaking(): void {
  it("Vault: stake and unstake tokens", async function () {
    const token = this.mockWETH;
    const investor = this.signers.investor;

    // Fund investor with a given wealth (through minting) and approve the vault
    const firstStakerWealth = BigNumber.from(10).pow(18).mul(2);
    await token.mintTo(investor.address, firstStakerWealth);
    await token.connect(investor).approve(this.vault.address, firstStakerWealth);

    // Get wrapped token contract
    const wrappedTokenAddress = (await this.vault.vaults(token.address)).wrappedToken;
    const wrappedToken = await ethers.getContractAt(ERC20.abi, wrappedTokenAddress);

    // Amount to stake
    const amountToStake = BigNumber.from(10).pow(18);

    // Amount to unstake
    const amountBack = BigNumber.from(10).pow(18);

    const initialState = {
      balance: await token.balanceOf(investor.address),
    };

    const stakeTx = await this.vault.connect(investor).stake(token.address, amountToStake);
    const stakeEvents = (await stakeTx.wait()).events;

    const middleState = {
      balance: await token.balanceOf(investor.address),
      wrappedBalance: await wrappedToken.balanceOf(investor.address),
    };

    expect(middleState.balance).to.equal(initialState.balance.sub(amountToStake));
    expect(middleState.wrappedBalance).to.equal(amountToStake);

    const validStakeEvents = stakeEvents?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validStakeEvents?.length).equal(1);

    // Transfer tokens to vault: it has the same effect of fee generation
    const amountAdded = BigNumber.from(10).pow(17);
    await token.mintTo(this.vault.address, amountAdded);

    // Withdrawing too much should revert
    await expect(this.vault.connect(investor).unstake(token.address, amountBack.add(amountAdded).add(1))).to.be
      .reverted;

    // Unstake maximum
    const unstakeTx = await this.vault.connect(investor).unstake(token.address, amountBack.add(amountAdded));
    const unstakeEvents = (await unstakeTx.wait()).events;

    const finalState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(finalState.balance).to.equal(initialState.balance.sub(amountToStake).add(amountBack).add(amountAdded));

    const validUnstakeEvents = unstakeEvents?.filter(
      event => event.event === "Withdrawal" && event.args && event.args[0] === investor.address,
    );
    expect(validUnstakeEvents?.length).equal(1);
  });

  it("Vault: stake and unstake ETH", async function () {
    const investor = this.signers.investor;
    const amount = ethers.utils.parseUnits("1.0", 18);
    const amountBack = ethers.utils.parseUnits("1.0", 18);

    const initialState = {
      balance: await this.provider.getBalance(investor.address),
    };

    const stakeTx = await this.vault.connect(investor).stakeETH(amount, { value: amount });
    const stakeEvents = await stakeTx.wait();

    const middleState = {
      balance: await this.provider.getBalance(investor.address),
    };

    const totalGasForStaking = stakeEvents.gasUsed.mul(stakeEvents.effectiveGasPrice);

    expect(middleState.balance).to.equal(initialState.balance.sub(amount).sub(totalGasForStaking));

    const validStakeEvents = stakeEvents.events?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validStakeEvents?.length).equal(1);

    const unstakeTx = await this.vault.connect(investor).unstakeETH(amountBack);
    const unstakeEvents = await unstakeTx.wait();

    const finalState = {
      balance: await this.provider.getBalance(investor.address),
    };

    const totalGasForUnstaking = unstakeEvents.gasUsed.mul(unstakeEvents.effectiveGasPrice);

    expect(finalState.balance).to.equal(middleState.balance.add(amount).sub(totalGasForUnstaking));

    const validUnstakeEvents = unstakeEvents.events?.filter(
      event => event.event === "Withdrawal" && event.args && event.args[0] === investor.address,
    );
    expect(validUnstakeEvents?.length).equal(1);
  });
}
