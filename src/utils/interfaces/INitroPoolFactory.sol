// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface INitroPoolFactory {
  function nftPoolPublishedNitroPoolsLength(address nftPoolAddress) external view returns (uint256);

  function getNftPoolPublishedNitroPool(address nftPoolAddress, uint256 index) external view returns (address);
}
