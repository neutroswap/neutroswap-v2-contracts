# 🛠 Neutroswap V2

Neutroswap V2 is the second iteration upgrading the existing protocol with additional features such as locked version of $NEUTRO token, NFT-based LP Token, and Plugins. For an extensive understanding of Neutroswap v2, please refer to our
[Documentation](https://docs.neutroswap.io/).

## 📁 Contracts

The `V1` directory contains the contracts for the version 1 of our project. Here is a brief overview of the contracts
included:

```text
├── NeutroChef
├── NeutroToken
```

> Farm emissions will be migrated to V2 contracts (NeutoMaster)

### 📜 Contracts Description

- **xNEUTRO:** The locked version and non-transferrable token of $NEUTRO with the purpose of providing utility for users by allocating xNEUTRO to various provided Plugins.
- **NeutroMaster:** Centralizes Neutro's yield incentives distribution.
- **NFTPoolFactory:** Factory pattern for creating NFT Pool.
- **NFTPool:** Wraps ERC20 assets into non-fungible staking positions called spNFTs. Yield-generating positions when the
  NFTPool contract has allocations from the Neutro Master.
- **NitroPoolFactory:** Factory pattern for creating Nitro Pool.
- **NitroPool:** spNFTs Pool for incentives position based on the determined position requirements and purposed for
  collaborating with other projects.
- **Dividends:** Plugin to distribute dividends to xNEUTRO allocators.
- **YieldBooster:** Plugin to boost spNFTs' yield (staking positions on NFTPools).
- **FairAuctionFactory:** Factory pattern for creating Fair Auction.
- **NeutroHelper:** Serving FE datas.
  > and more plugins to come 🥳 ..

## 💻 Developer Guide

We use **Foundry** as the framework of our contracts. To install Foundry, the recommended method is to use `foundryup`. Run
the following commands to install and fetch the latest version: For detailed installation instructions, please refer to
the [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation)

Running the test:

```sh
$ npm run test
```

## 🙏 Acknowledgments

Many thanks to PaulRBerg for the template. Explore it here:
[Foundry Template](https://github.com/PaulRBerg/foundry-template)
