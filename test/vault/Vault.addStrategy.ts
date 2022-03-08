import { expect } from "chai";
import { addresses } from "../../deployments/addresses.json";

export function checkAddStrategy(): void {
  it("check addStrategy", async function () {
    const strategy = addresses.MarginTradingStrategy;

    const initialState = {
      strategyAdded: await this.vault.strategies(strategy),
    };

    const rsp = await this.vault.addStrategy(strategy);
    const events = (await rsp.wait()).events;

    const finalState = {
      strategyAdded: await this.vault.strategies(strategy),
    };

    expect(initialState.strategyAdded).to.equal(false);
    expect(finalState.strategyAdded).to.equal(true);

    const validEvents = events?.filter(
      event => event.event === "StrategyWasAdded" && event.args && event.args[0] === strategy,
    );
    expect(validEvents?.length).to.equal(1);
  });

  it("check removeStrategy", async function () {
    const strategy = addresses.MarginTradingStrategy;

    await this.vault.addStrategy(strategy);

    const initialState = {
      strategyAdded: await this.vault.strategies(strategy),
    };

    const rsp = await this.vault.removeStrategy(strategy);
    const events = (await rsp.wait()).events;

    const finalState = {
      strategyAdded: await this.vault.strategies(strategy),
    };

    expect(initialState.strategyAdded).to.equal(true);
    expect(finalState.strategyAdded).to.equal(false);

    const validEvents = events?.filter(
      event => event.event === "StrategyWasRemoved" && event.args && event.args[0] === strategy,
    );
    expect(validEvents?.length).to.equal(1);
  });
}
