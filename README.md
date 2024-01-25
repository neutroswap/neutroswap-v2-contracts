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
- **PositionHelper:** Helper for instantly create LP token and wrap it up to spNFT.
  > and more plugins to come 🥳 ..

### Testnet contracts

- **xNEUTRO:** `0xA3100a831B007A12ab0a3639C99C8b2C9765c4f9` <br />
- **NeutroMaster:** `0x599b77c80DFA5D7E0C49Fa718308Fa4d9a0d8DE0` <br />
- **NFTPoolFactory:** `0x47ad9f7A7Ca90dDA7B362a3e33CD31e7B74A167c` <br />
- **NitroPoolFactory:** `0x6A45C6455067586F3C100714e9c6b03BBc65Ff71` <br />
- **Dividends:** `0x749e4ab18F594092b690c9d4E961A7A1853D2DFe` <br />
- **YieldBooster:** `0xF274E1f39f738EBa46B6acAe6D80EEF44b98d1E7` <br />
- **FairAuctionFactory:** `0x2785110AB14d0429B02Bc048bA14F0905C3E2A9f` <br />
- **NeutroHelper:** `0x135AabC332c43f7c1dF6e816d9b9d276420AECf6` <br />
- **PositionHelper:** `0xDD26d7AF731aAA6A09587B716614F6aFE9D099B8` <br />

## 💻 Developer Guide

We use **Foundry** as the framework of our contracts. To install Foundry, the recommended method is to use `foundryup`. Run
the following commands to install and fetch the latest version: For detailed installation instructions, please refer to
the [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation)

Build contracts:

```sh
$ forge build
```

Running the test:

```sh
$ forge test
```

## 🙏 Acknowledgments

Many thanks to PaulRBerg for the template. Explore it here:
[Foundry Template](https://github.com/PaulRBerg/foundry-template)
