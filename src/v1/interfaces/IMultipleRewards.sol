// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "../interfaces/IBoringERC20.sol";

interface IMultipleRewards {
    function onNeutroReward(
        uint256 pid,
        address user,
        uint256 newLpAmount
    ) external;

    function pendingTokens(uint256 pid, address user)
        external
        view
        returns (uint256 pending);

    function rewardToken() external view returns (IBoringERC20);

    function poolRewardsPerSec(uint256 pid) external view returns (uint256);
}
