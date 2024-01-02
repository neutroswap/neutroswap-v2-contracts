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

### Testnet contracts

- **xNEUTRO:** `0x96A064DB6CA1D45e59756D3DAc7CD249D4D742030` <br />
- **NeutroMaster:** `0x9Ab3817b1c376166b2c52CA98805D3873f219905` <br />
- **NFTPoolFactory:** `0x8105258c5edB1b0C6be6b70AD301E518eBC0651a` <br />
- **NitroPoolFactory:** `0x5f4b3D92bcb944a0e9B231C42D0615F8A27Bbcc0` <br />
- **Dividends:** `0xD442238e866C8Fd3EF1C83D5a3fCC3012C822046` <br />
- **YieldBooster:** `0x11cD095C60534DD3983A3d83D691d148bEcEB89E` <br />
- **FairAuctionFactory:** `0x72076068Bd08f5D0AE541075f1E317b3B1d46d8f` <br />
- **NeutroHelper:** `0x826c1Bbf83ae7bA618c4874cE133F2a7029487Fd` <br />

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
