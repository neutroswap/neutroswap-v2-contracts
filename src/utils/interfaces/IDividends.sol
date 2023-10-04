// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IDividends {
  function distributedTokensLength() external view returns (uint256);

  function distributedToken(uint256 index) external view returns (address);

  function isDistributedToken(address token) external view returns (bool);

  function addDividendsToPending(address token, uint256 amount) external;

  function usersAllocation(address userAddress) external view returns (uint256);

  function pendingDividendsAmount(address token, address userAddress) external view returns (uint256);

  function dividendsInfo(address token)
    external
    view
    returns (
      uint256 currentDistributionAmount,
      uint256 currentCycleDistributedAmount,
      uint256 pendingAmount,
      uint256 distributedAmount,
      uint256 accDividendsPerShare,
      uint256 lastUpdateTime,
      uint256 cycleDividendsPercent,
      bool distributionDisabled
    );
}
