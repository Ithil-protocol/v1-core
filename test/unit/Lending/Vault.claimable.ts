import { expect } from "chai";
import { mintAndStake, expandToNDecimals } from "../../common/utils";

export function checkClaimable(): void {
  it("Vault: claimable", async function () {
    const token = this.mockWETH;
    const investor = this.signers.investor;

    // Initial status
    const initialClaimable = await this.vault.connect(investor).claimable(token.address);
    expect(initialClaimable).to.equal(0);

    // Stake and check claimable value
    const amountToStake = expandToNDecimals(1000, 18);
    const initialStakerLiquidity = expandToNDecimals(10000, 18);
    await mintAndStake(investor, this.vault, token, initialStakerLiquidity, amountToStake);

    const claimable = await this.vault.connect(investor).claimable(token.address);

    expect(claimable).to.equal(amountToStake);
  });
}
