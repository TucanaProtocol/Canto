// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IChain.sol";
import "./interfaces/IReward.sol";

contract Reward is Initializable, OwnableUpgradeable, IReward {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(address => mapping(address => uint256)) private rewardPerTokenStored;
    mapping(address => mapping(address => mapping(address => uint256))) private userRewardPerTokenPaid;
    mapping(address => uint256) private rewards;
    IERC20Upgradeable public rewardToken;
    IConfig public config;
    IChain public chain;
    address public lendAddress;

    /// @notice Modifier to restrict function access to only the lend contract
    /// @dev Reverts if the caller is not the lend contract
    modifier onlyLend() {
        require(msg.sender == lendAddress, "Reward: Only lend contract can call this function");
        _;
    }

    /// @notice Initializes the contract with configuration, reward token, and chain addresses
    /// @param _configAddress Address of the config contract
    /// @param _rewardToken Address of the reward token
    /// @param _chainAddress Address of the chain contract
    /// @dev This function can only be called once due to the initializer modifier
    function initialize(address _configAddress, address _rewardToken, address _chainAddress) public initializer {
        __Ownable_init();
        config = IConfig(_configAddress);
        rewardToken = IERC20Upgradeable(_rewardToken);
        chain = IChain(_chainAddress);
    }
    
    /// @notice Sets the lend contract address
    /// @param _lendAddress Address of the lend contract
    /// @dev Can only be called by the contract owner
    function setLendContract(address _lendAddress) external onlyOwner {
        lendAddress = _lendAddress;
    }
    
    /// @notice Sets the reward token address
    /// @param _rewardToken Address of the new reward token
    /// @dev Can only be called by the contract owner
    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20Upgradeable(_rewardToken);
    }

    /// @notice Updates the reward for a specific user
    /// @param user Address of the user to update rewards for
    /// @dev Calculates and stores earned rewards, updates user reward per token paid
    function updateReward(address user) public {
        uint256 earnedAmount = earned(user);
        rewards[user] += earnedAmount;

        address[] memory validators = chain.getValidators();
        for (uint256 i = 0; i < validators.length; i++) {
            address validator = validators[i];
            address[] memory lpTokens = config.getAllWhitelistTokens();
            for (uint256 j = 0; j < lpTokens.length; j++) {
                address lpToken = lpTokens[j];
                updateUserRewardPerTokenPaid(user, lpToken, validator);
            }
        }
    }

    /// @notice Calculates the total earned rewards for a user
    /// @param user Address of the user to calculate rewards for
    /// @return totalEarned The total amount of rewards earned by the user
    function earned(address user) public view returns (uint256) {
        uint256 totalEarned = 0;
        address[] memory validators = chain.getValidators();
        for (uint256 i = 0; i < validators.length; i++) {
            address validator = validators[i];
            address[] memory lpTokens = config.getAllWhitelistTokens();
            for (uint256 j = 0; j < lpTokens.length; j++) {
                address lpToken = lpTokens[j];
                uint256 userValidatorTokenStake = chain.getUserValidatorTokenStake(user, validator, lpToken);
                uint256 rewardPerToken = getRewardPerTokenStored(lpToken, validator);
                uint256 userRewardPaid = getUserRewardPaid(user, lpToken, validator);
                totalEarned += (userValidatorTokenStake * (rewardPerToken - userRewardPaid)) / (10**config.getPrecision());
            }
        }
        return totalEarned;
    }

    /// @notice Allows a user to claim their accumulated rewards
    /// @dev Updates rewards before claiming and transfers the reward tokens to the user
    function claimReward() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    /// @notice Calculates the claimable reward for a user
    /// @param user Address of the user to check claimable rewards for
    /// @return The total amount of claimable rewards for the user
    function claimableReward(address user) external view returns (uint256) {
        return rewards[user] + earned(user);
    }

    /// @notice Distributes rewards to validators for different LP tokens
    /// @param validators Array of validator addresses
    /// @param lpTokens Array of LP token addresses
    /// @param rewardAmounts 2D array of reward amounts for each validator and LP token
    /// @dev Can only be called by the contract owner
    function distributeReward(
        address[] memory validators,
        address[] memory lpTokens,
        uint256[][] memory rewardAmounts
    ) external onlyOwner {
        require(rewardAmounts.length == validators.length, "Reward: Length mismatch validators");
        uint256 totalRewardAmount = 0;

        for (uint256 i = 0; i < validators.length; i++) {
            require(rewardAmounts[i].length == lpTokens.length, "Reward: Length mismatch lpTokens");
            for (uint256 j = 0; j < lpTokens.length; j++) {
                uint256 rewardAmount = rewardAmounts[i][j];
                address validator = validators[i];
                address lpToken = lpTokens[j];
                uint256 validatorTokenStake = chain.getValidatorTokenStake(validator, lpToken);
                if (validatorTokenStake == 0) continue;

                uint256 perTokenRewardIncrease = (rewardAmount * (10**config.getPrecision())) / validatorTokenStake;
                totalRewardAmount += rewardAmount;
                updateRewardPerTokenStored(lpToken, validator, perTokenRewardIncrease);

                emit RewardDistributed(validator, lpToken, perTokenRewardIncrease);
            }
        }

        if (totalRewardAmount > 0) {
            rewardToken.safeTransferFrom(msg.sender, address(this), totalRewardAmount);
        }
    }

    /// @notice Updates the user's reward per token paid for a specific LP token and validator
    /// @param user Address of the user
    /// @param lpToken Address of the LP token
    /// @param validator Address of the validator
    /// @dev Internal function to update user-specific reward tracking
    function updateUserRewardPerTokenPaid(address user, address lpToken, address validator) internal {
        uint256 rewardPerTokenStored = getRewardPerTokenStored(lpToken, validator);
        userRewardPerTokenPaid[user][validator][lpToken] = rewardPerTokenStored;
    }

    /// @notice Retrieves the stored reward per token for a specific LP token and validator
    /// @param lpToken Address of the LP token
    /// @param validator Address of the validator
    /// @return The stored reward per token
    function getRewardPerTokenStored(address lpToken, address validator) public view returns (uint256) {
        return rewardPerTokenStored[validator][lpToken];
    }

    /// @notice Updates the stored reward per token for a specific LP token and validator
    /// @param lpToken Address of the LP token
    /// @param validator Address of the validator
    /// @param rewardPerToken Amount to increase the reward per token by
    /// @dev Internal function to update global reward tracking
    function updateRewardPerTokenStored(address lpToken, address validator, uint256 rewardPerToken) internal {
        rewardPerTokenStored[validator][lpToken] += rewardPerToken;
    }

    /// @notice Retrieves the user's paid reward per token for a specific LP token and validator
    /// @param user Address of the user
    /// @param lpToken Address of the LP token
    /// @param validator Address of the validator
    /// @return The user's paid reward per token
    function getUserRewardPaid(address user, address lpToken, address validator) public view returns (uint256) {
        return userRewardPerTokenPaid[user][validator][lpToken];
    }
}
