// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IReward.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Reward is Initializable, OwnableUpgradeable, IReward {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private rewardTokens;
    //rewardToken => lpToken => amount
    mapping(address => mapping(address => uint256)) private rewardPerTokenStored;
    //user => rewardToken => lpToken => amount
    mapping(address => mapping(address => mapping(address => uint256))) private userRewardPerTokenPaid;

    //user => rewardToken => amount
    mapping(address => mapping(address => uint256)) private rewards;
    IConfig public config;
    IPool public pool;
    address public lendAddress;

    /// @notice Modifier to restrict function access to only the lend contract
    /// @dev Reverts if the caller is not the lend contract
    modifier onlyLend() {
        require(msg.sender == lendAddress, "Reward: Only lend contract can call this function");
        _;
    }

    /// @notice Initializes the contract with configuration and pool addresses
    /// @param _configAddress Address of the config contract
    /// @param _poolAddress Address of the pool contract
    /// @dev This function can only be called once due to the initializer modifier
    function initialize(address _configAddress, address _poolAddress) public initializer {
        __Ownable_init();
        config = IConfig(_configAddress);
        pool = IPool(_poolAddress);
    }
    
    /// @notice Sets the lend contract address
    /// @param _lendAddress Address of the lend contract
    /// @dev Can only be called by the contract owner
    function setLendContract(address _lendAddress) external onlyOwner {
        lendAddress = _lendAddress;
    }

    /// @notice Updates the reward for a specific user
    /// @param user Address of the user to update rewards for
    /// @dev Calculates and stores earned rewards, updates user reward per token paid
    function updateReward(address user) public {
        for (uint256 i = 0; i < rewardTokens.length(); i++) {
            address rewardToken = rewardTokens.at(i);
            uint256 earnedAmount = earned(user, rewardToken);
            rewards[user][rewardToken] += earnedAmount;

            address[] memory lpTokens = config.getAllWhitelistTokens();
            for (uint256 j = 0; j < lpTokens.length; j++) {
                address lpToken = lpTokens[j];
                updateUserRewardPerTokenPaid(user, rewardToken, lpToken);
            }
        }
    }

    /// @notice Calculates the total earned rewards for a user for a specific reward token
    /// @param user Address of the user to calculate rewards for
    /// @param rewardToken Address of the reward token
    /// @return totalEarned The total amount of rewards earned by the user for the reward token
    function earned(address user, address rewardToken) public view returns (uint256) {
        uint256 totalEarned = 0;
        address[] memory lpTokens = config.getAllWhitelistTokens();
        for (uint256 i = 0; i < lpTokens.length; i++) {
            address lpToken = lpTokens[i];
            uint256 userTokenSupply = pool.getUserTokenSupply(user, lpToken);
            uint256 rewardPerToken = getRewardPerTokenStored(rewardToken, lpToken);
            uint256 userRewardPaid = getUserRewardPaid(user, rewardToken, lpToken);
            totalEarned += (userTokenSupply * (rewardPerToken - userRewardPaid)) / (10**config.getPrecision());
        }
        return totalEarned;
    }

    /// @notice Allows a user to claim their accumulated rewards for a specific reward token
    /// @param rewardToken Address of the reward token to claim
    /// @dev Updates rewards before claiming and transfers the reward tokens to the user
    function claimReward(address rewardToken) external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender][rewardToken];
        if (reward > 0) {
            rewards[msg.sender][rewardToken] = 0;
            IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, rewardToken, reward);
        }
    }

    /// @notice Calculates the claimable reward for a user for a specific reward token
    /// @param user Address of the user to check claimable rewards for
    /// @param rewardToken Address of the reward token
    /// @return The total amount of claimable rewards for the user for the reward token
    function claimableReward(address user, address rewardToken) external view returns (uint256) {
        return rewards[user][rewardToken] + earned(user, rewardToken);
    }

    /// @notice Distributes rewards to token suppliers for different LP tokens
    /// @param _rewardTokens Array of reward token addresses to distribute
    /// @param _lpTokens Array of LP token addresses
    /// @param _rewardAmounts 2D array of reward amounts for each reward token and LP token
    /// @dev Can only be called by the contract owner
    function distributeReward(
        address[] memory _rewardTokens,
        address[] memory _lpTokens,
        uint256[][] memory _rewardAmounts
    ) external onlyOwner {
        require(_rewardTokens.length == _rewardAmounts.length, "Reward: Length mismatch");
        require(_lpTokens.length == _rewardAmounts[0].length, "Reward: Length mismatch");

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            address rewardToken = _rewardTokens[i];
            uint256 totalRewardAmount = 0;

            for (uint256 j = 0; j < _lpTokens.length; j++) {
                uint256 rewardAmount = _rewardAmounts[i][j];
                address lpToken = _lpTokens[j];
                uint256 totalTokenSupply = pool.totalSupply(lpToken);
                if (totalTokenSupply == 0) continue;

                uint256 perTokenRewardIncrease = (rewardAmount * (10**config.getPrecision())) / totalTokenSupply;
                totalRewardAmount += rewardAmount;
                updateRewardPerTokenStored(rewardToken, lpToken, perTokenRewardIncrease);

                emit RewardDistributed(rewardToken, lpToken, perTokenRewardIncrease);
            }

            if (totalRewardAmount > 0) {
                IERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewardAmount);
            }
        }
    }

    /// @notice Updates the user's reward per token paid for a specific reward token and LP token
    /// @param user Address of the user
    /// @param rewardToken Address of the reward token
    /// @param lpToken Address of the LP token
    /// @dev Internal function to update user-specific reward tracking
    function updateUserRewardPerTokenPaid(address user, address rewardToken, address lpToken) internal {
        uint256 rewardPerTokenStoredLocal = getRewardPerTokenStored(rewardToken, lpToken);
        userRewardPerTokenPaid[user][rewardToken][lpToken] = rewardPerTokenStoredLocal;
    }

    /// @notice Retrieves the stored reward per token for a specific reward token and LP token
    /// @param rewardToken Address of the reward token
    /// @param lpToken Address of the LP token
    /// @return The stored reward per token
    function getRewardPerTokenStored(address rewardToken, address lpToken) public view returns (uint256) {
        return rewardPerTokenStored[rewardToken][lpToken];
    }

    /// @notice Updates the stored reward per token for a specific reward token and LP token
    /// @param rewardToken Address of the reward token
    /// @param lpToken Address of the LP token
    /// @param rewardPerToken Amount to increase the reward per token by
    /// @dev Internal function to update global reward tracking
    function updateRewardPerTokenStored(address rewardToken, address lpToken, uint256 rewardPerToken) internal {
        rewardPerTokenStored[rewardToken][lpToken] += rewardPerToken;
    }

    /// @notice Retrieves the user's paid reward per token for a specific reward token and LP token
    /// @param user Address of the user
    /// @param rewardToken Address of the reward token
    /// @param lpToken Address of the LP token
    /// @return The user's paid reward per token
    function getUserRewardPaid(address user, address rewardToken, address lpToken) public view returns (uint256) {
        return userRewardPerTokenPaid[user][rewardToken][lpToken];
    }

    /// @notice Retrieves all the supported reward tokens
    /// @return An array of addresses representing the supported reward tokens
    function getAllRewardTokens() external view returns (address[] memory) {
        return rewardTokens.values();
    }
    
    /// @notice Adds a new reward token to the list of supported reward tokens
    /// @param rewardToken Address of the reward token to add
    /// @dev Can only be called by the contract owner
    function addRewardToken(address rewardToken) external onlyOwner {
        rewardTokens.add(rewardToken);
    }

    /// @notice Removes a reward token from the list of supported reward tokens
    /// @param rewardToken Address of the reward token to remove
    /// @dev Can only be called by the contract owner
    function removeRewardToken(address rewardToken) external onlyOwner {
        rewardTokens.remove(rewardToken);
    }
}
