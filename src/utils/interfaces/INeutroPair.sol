// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface INeutroPair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves()
    external
    view
    returns (
      uint112 _reserve0,
      uint112 _reserve1,
      uint32 _blockTimestampLast
    );
}
