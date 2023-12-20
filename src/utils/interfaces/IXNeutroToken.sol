// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXNeutroToken is IERC20 {
  function usageAllocations(address userAddress, address usageAddress) external view returns (uint256 allocation);

  function allocateFromUsage(address userAddress, uint256 amount) external;

  function convertTo(uint256 amount, address to) external;

  function deallocateFromUsage(address userAddress, uint256 amount) external;

  function usagesDeallocationFee(address usageAddress) external view returns (uint256);

  function isTransferWhitelisted(address account) external view returns (bool);

  function getUserRedeemsLength(address userAddress) external view returns (uint256);

  function getUserRedeem(address userAddress, uint256 redeemIndex)
    external
    view
    returns (
      uint256 neutroAmount,
      uint256 xNeutroAmount,
      uint256 endTime,
      address dividendsContract,
      uint256 dividendsAllocation
    );
}
