import { expect } from "chai";
import { artifacts, ethers, waffle } from "hardhat";

import { tokens } from "../common/mainnet";

describe("Create3 deployer tests", function () {
  it("deploy", async function () {
    const VaultDeployer = await ethers.getContractFactory("VaultDeployer");
    const vaultDeployer = await VaultDeployer.deploy();
    await vaultDeployer.deploy(tokens.WETH.address);
    const vault = await vaultDeployer.vault();
    expect(vault).not.to.equal("0x0000000000000000000000000000000000000000");
    expect(vault).to.equal(await vaultDeployer.getDeployed());

    const StakerDeployer = await ethers.getContractFactory("StakerDeployer");
    const stakerDeployer = await StakerDeployer.deploy();
    await stakerDeployer.deploy(tokens.WETH.address);
    const staker = await stakerDeployer.staker();
    expect(staker).not.to.equal("0x0000000000000000000000000000000000000000");
    expect(staker).to.equal(await stakerDeployer.getDeployed());

    const LiquidatorDeployer = await ethers.getContractFactory("LiquidatorDeployer");
    const liquidatorDeployer = await LiquidatorDeployer.deploy();
    await liquidatorDeployer.deploy(staker);
    const liquidator = await liquidatorDeployer.liquidator();
    expect(liquidator).not.to.equal("0x0000000000000000000000000000000000000000");
    expect(liquidator).to.equal(await liquidatorDeployer.getDeployed());
  });
});
