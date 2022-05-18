import { expect } from "chai";

export function checkLock(): void {
  it("Vault: toggle lock", async function () {
    const token = this.mockWETH;

    // Initial status should be unlocked
    const initialLock = (await this.vault.vaults(token.address)).locked;
    expect(initialLock).to.equal(false);

    // Toggle lock
    await this.vault.connect(this.signers.admin).toggleLock(true, token.address);

    // Final status should be locked
    const finalLock = (await this.vault.vaults(token.address)).locked;
    expect(finalLock).to.equal(true);
  });
}
