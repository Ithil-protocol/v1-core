import { expect } from "chai";
import { mintAndStake, expandTo18Decimals } from "../../common/utils";

export function checkClaimable(): void {
  it("Vault: claimable", async function () {
    const token = this.mockWETH;
    const investor = this.signers.investor;

    // Amount to stake
    const amountToStake = expandTo18Decimals(1000);
    // Initial staker's liquidity
    const initialStakerLiquidity = expandTo18Decimals(10000);
    await mintAndStake(investor, this.vault, token, initialStakerLiquidity, amountToStake);

    const claimable = await this.vault.connect(investor).claimable(token.address);

    expect(claimable).to.be.above(amountToStake);
  });
}
