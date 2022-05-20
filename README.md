<div align="center">
![ithil](header.png)
</div>

<h1 align="center">Ithil Protocol V1</h1>

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-0.8.12-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black) ![NodeJS](https://img.shields.io/badge/Node.js-16.x-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)

[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/tEaGBcGdQC) [![Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ithil_protocol) [![Website](https://img.shields.io/badge/Website-E34F26?style=for-the-badge&logo=Google-chrome&logoColor=white)](https://ithil.fi/) [![Docs](https://img.shields.io/badge/Docs-7B36ED?style=for-the-badge&logo=gitbook&logoColor=white)](https://docs.ithil.fi/)

</div>

> Ithil is the first decentralised DeFi hedge fund to perform undercollateralised leveraged investments on virtually any DeFi protocol.

This repository contains the core smart contracts for Ithil V1.

## Key Features

- Perform leveraged investments on a wide pool of strategies, get huge payoffs with a small starting capital
- Provide liquidity in almost any token you like, from stablecoins to meme and rebasing tokens and get APY in that same token
- Contribute to safeguarding the protocol by liquidating positions at loss and get rewarded
- Develop new strategies and expand the trading possibilities

## Installation

Prerequisites for this project are:

- NodeJS v16.x
- Yarn
- Git

To get a copy of the source

```bash
git clone https://github.com/Ithil-protocol/v1-core
cd v1-core
yarn install
```

## Usage

Create an environment file `.env` copying the template environment file

```bash
cp .env.example .env
```

and add the following content:

```text
ALCHEMY_API_KEY=your alchemy.com api key
FORKING=true to enable mainnet fork
REPORT_GAS=true to enable gas report at the end of tests
```

Load it in your local env with `source .env` and finally you can compile the contracts:

```bash
npx hardhat compile
```

This project uses `hardhat`, `typechain` to produce TypeScript bindings and `waffle` for tests, you can find the compiler configurations in `hardhat.config.ts`.

## Test

```bash
yarn test
```

You can also check code coverage with the following command:

```bash
yarn coverage
```

## Security

If you find bugs, please follow the instructions on the SECURITY.md file. We have a bug bounty program that covers the main source files.

## Documentation

You can read more about Ithil on our [documentation website](https://docs.ithil.fi/).

## Licensing

The main license for the Ithil contracts is the Business Source License 1.1 (BUSL-1.1), see LICENSE file to learn more. The Solidity files licensed under the BUSL-1.1 have appropriate SPDX headers.

## Disclamer

This application is provided "as is" and "with all faults." Me as developer makes no representations or warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical errors, or other harmful components of this software. There are inherent dangers in the use of any software, and you are solely responsible for determining whether this software product is compatible with your equipment and other software installed on your equipment. You are also solely responsible for the protection of your equipment and backup of your data, and THE PROVIDER will not be liable for any damages you may suffer in connection with using, modifying, or distributing this software product.
