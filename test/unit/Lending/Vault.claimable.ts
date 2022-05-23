import { expect } from "chai";
import { mintAndStake, expandTo18Decimals } from "../../common/utils";

export function checkClaimable(): void {
  it("Vault: claimable", async function () {
    const token = this.mockWETH;
    const investor = this.signers.investor;

    // Initial status
    const initialClaimable = await this.vault.connect(investor).claimable(token.address);
    expect(initialClaimable).to.equal(0);

    // Stake and check claimable value
    const amountToStake = expandTo18Decimals(1000);
    const initialStakerLiquidity = expandTo18Decimals(10000);
    await mintAndStake(investor, this.vault, token, initialStakerLiquidity, amountToStake);

    const claimable = await this.vault.connect(investor).claimable(token.address);

    expect(claimable).to.equal(amountToStake);
  });
}
