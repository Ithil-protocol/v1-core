import { expect } from "chai";
import { ethers } from "hardhat";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { mintAndStake, expandTo18Decimals } from "../../common/utils";

export function checkStaking(): void {
  it("Vault: stake and unstake tokens", async function () {
    const token = this.mockWETH;
    const investor = this.signers.investor;

    // Get wrapped token contract
    const wrappedTokenAddress = (await this.vault.vaults(token.address)).wrappedToken;
    const wrappedToken = await ethers.getContractAt(ERC20.abi, wrappedTokenAddress);

    // Amount to stake
    const amountToStake = expandTo18Decimals(1000);
    // Initial staker's liquidity
    const initialStakerLiquidity = expandTo18Decimals(10000);
    // Amount to unstake
    const amountBack = expandTo18Decimals(1000);

    const stakeTx = await mintAndStake(investor, this.vault, token, initialStakerLiquidity, amountToStake);
    const stakeEvents = (await stakeTx.wait()).events;

    const middleState = {
      balance: await token.balanceOf(investor.address),
      wrappedBalance: await wrappedToken.balanceOf(investor.address),
    };

    expect(middleState.wrappedBalance).to.equal(amountToStake);

    const validStakeEvents = stakeEvents?.filter(
      event => event.event === "Deposit" && event.args && event.args[0] === investor.address,
    );
    expect(validStakeEvents?.length).equal(1);

    // Transfer tokens to vault: it has the same effect of fee generation
    const amountAdded = expandTo18Decimals(100);
    await token.mintTo(this.vault.address, amountAdded);

    // Withdrawing too much should revert
    await expect(this.vault.connect(investor).unstake(token.address, amountToStake.add(amountAdded).add(1))).to.be
      .reverted;

    // Unstake maximum
    const unstakeTx = await this.vault.connect(investor).unstake(token.address, amountBack.add(amountAdded));
    const unstakeEvents = (await unstakeTx.wait()).events;

    const finalState = {
      balance: await token.balanceOf(investor.address),
    };

    expect(finalState.balance).to.equal(initialStakerLiquidity.sub(amountToStake).add(amountBack).add(amountAdded));

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
