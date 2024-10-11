// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IReward {
    event RewardDistributed(address indexed rewardToken, address indexed lpToken, uint256 perTokenRewardIncrease);
    event RewardClaimed(address indexed user, address indexed rewardToken, uint256 amount);

    function updateReward(address user) external;
    function earned(address user, address rewardToken) external view returns (uint256);
    function claimReward(address rewardToken) external;
    function claimableReward(address user, address rewardToken) external view returns (uint256);
    function distributeReward(
        address[] memory rewardTokens,
        address[] memory lpTokens,
        uint256[][] memory rewardAmounts
    ) external;
    function getRewardPerTokenStored(address rewardToken, address lpToken) external view returns (uint256);
    function getUserRewardPaid(address user, address rewardToken, address lpToken) external view returns (uint256);
}
