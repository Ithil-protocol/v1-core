import { expect } from "chai";
import { ethers } from "hardhat";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";
import { expandTo18Decimals } from "../../common/utils";

export function checkTreasuryStaking(): void {
  it("Vault: treasury stake", async function () {
    // const token = this.mockWETH;
    // const treasury = this.signers.admin;
    // // Get wrapped token contract
    // const wrappedTokenAddress = (await this.vault.vaults(token.address)).wrappedToken;
    // const wrappedToken = await ethers.getContractAt(ERC20.abi, wrappedTokenAddress);
    // // Amount to stake
    // const amountToStake = expandTo18Decimals(1000);
    // // Initial staker's liquidity
    // const initialTreasuryLiquidity = expandTo18Decimals(10000);
    // // give tokens to the treasury and approve the vault
    // await token.mintTo(treasury.address, initialTreasuryLiquidity);
    // await token.connect(treasury).approve(this.vault.address, initialTreasuryLiquidity);
    // // Treasury stakes
    // await this.vault.connect(treasury).treasuryStake(token.address, amountToStake);
    // const middleState = {
    //   balance: await token.balanceOf(treasury.address),
    //   wrappedBalance: await wrappedToken.balanceOf(treasury.address),
    //   treasuryLiquidityStaked: (await this.vault.vaults(token.address)).treasuryLiquidity,
    // };
    // expect(middleState.wrappedBalance).to.equal(0);
    // expect(middleState.treasuryLiquidityStaked).to.equal(amountToStake);
    // // Transfer tokens to vault: it has the same effect of fee generation
    // const amountAdded = expandTo18Decimals(100);
    // await token.mintTo(this.vault.address, amountAdded);
    // // Even after transfer, treasury should not be able to withdraw too much
    // await expect(this.vault.connect(treasury).treasuryUnstake(token.address, amountToStake.add(1))).to.be.reverted;
    // // Unstake the treasury liquidity
    // await this.vault.connect(treasury).treasuryUnstake(token.address, amountToStake);
    // const finalState = {
    //   balance: await token.balanceOf(treasury.address),
    // };
    // expect(finalState.balance).to.equal(initialTreasuryLiquidity);
  });
}
