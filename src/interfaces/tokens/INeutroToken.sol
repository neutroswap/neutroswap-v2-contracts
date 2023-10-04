// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INeutroToken is IERC20 {
  function mint(address to, uint256 amount) external;

  function getMaxTotalSupply() external view returns (uint256);

  function burn(uint256 amount) external;
}
