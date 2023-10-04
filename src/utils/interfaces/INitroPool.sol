// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface INitroPool {
  function rewardsToken1PerSecond() external view returns (uint256);

  function rewardsToken2PerSecond() external view returns (uint256);

  function nftPool() external view returns (address);

  function rewardsToken1()
    external
    view
    returns (
      address token,
      uint256 amount,
      uint256 remainingAmount,
      uint256 accRewardsPerShare
    );

  function rewardsToken2()
    external
    view
    returns (
      address token,
      uint256 amount,
      uint256 remainingAmount,
      uint256 accRewardsPerShare
    );

  function totalDepositAmount() external view returns (uint256);
}
