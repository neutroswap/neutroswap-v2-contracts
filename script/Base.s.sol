// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
  // /// @dev Needed for the deterministic deployments.
  // bytes32 internal constant ZERO_SALT = bytes32(0);

  /// @dev The address of the transaction broadcaster.
  address internal broadcaster;

  /// @dev Initializes the transaction broadcaster
  ///
  /// - derive the broadcaster address from $ETH_FROM.
  ///
  /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
  constructor() {
    address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
    if (from != address(0)) {
      broadcaster = from;
    }
  }

  modifier broadcast() {
    vm.startBroadcast(broadcaster);
    _;
    vm.stopBroadcast();
  }
}