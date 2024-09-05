// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IChain.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IReward.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/ILend.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lend is Initializable, OwnableUpgradeable, PausableUpgradeable, ILend {
    using SafeERC20 for IERC20;
    IChain public chain;
    IPool public pool;
    IConfig public config;
    IReward public reward;
    IPriceFeed public priceFeed;
    IERC20Metadata public usd;
    mapping(address => bool) public plugin;

    event IncreaseSupplyEvent(address indexed account, address indexed tokenType, uint256 amount, address indexed validator);
    event IncreaseBorrowEvent(address indexed account, uint256 amount);
    event DecreaseSupplyEvent(address indexed account, address indexed tokenType, uint256 amount, address indexed validator);
    event RepayEvent(address indexed account, uint256 amount);
    event LiquidateEvent(address indexed liquidator, address indexed liquidatedUser, uint256 repayAmount);


    modifier onlyPlugin() {
        require(plugin[msg.sender], "Lend: Only plugin can call this function");
        _;
    }
    /**
     * @dev Initializes the contrpluginSupplyact with the given addresses.
     * @param _chainAddress The address of the Chain contract.
     * @param _poolAddress The address of the Pool contract.
     * @param _configAddress The address of the Config contract.
     * @param _rewardAddress The address of the Reward contract.
     * @param _priceFeedAddress The address of the PriceFeed contract.
     * @param _usdAddress The address of the USD token contract.
     */
    function initialize(
        address _chainAddress,
        address _poolAddress,
        address _configAddress,
        address _rewardAddress,
        address _priceFeedAddress,
        address _usdAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        chain = IChain(_chainAddress);
        pool = IPool(_poolAddress);
        config = IConfig(_configAddress);
        reward = IReward(_rewardAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        usd = IERC20Metadata(_usdAddress);
    }
    
    function setPlugin(address _plugin, bool _isPlugin) external onlyOwner {
        plugin[_plugin] = _isPlugin;
    }

    function pluginSupply(address user, address tokenType, uint256 amount, address validator) external whenNotPaused onlyPlugin {
        _supply(user, tokenType, amount, validator);
    }


    function pluginWithdraw(address user, address tokenType, uint256 amount, address validator) external whenNotPaused onlyPlugin {
        _withdraw(user, msg.sender, tokenType, amount, validator);
    }


    /**
     * @dev Supplies tokens to the pool and stakes them with a validator.
     * @param tokenType The address of the token to supply.
     * @param amount The amount of tokens to supply.
     * @param validator The address of the validator to stake with.
     *
     * This function performs the following steps:
     * 1. Updates the reward for the caller using the Reward contract.
     * 2. Checks if the token type is whitelisted in the Config contract.
     * 3. Transfers the specified amount of tokens from the caller to the Pool contract.
     * 4. Calls the internal _increaseAndStake function, which:
     *    - Calls Pool.increasePoolToken to increase the user's supply in the pool.
     *    - Calls ChainContract.stakeToken to stake the tokens with the specified validator.
     * 5. Emits an IncreaseSupplyEvent to log the supply action.
     *
     * This function interacts with:
     * - Reward.sol: Updates the user's reward.
     * - Config.sol: Checks if the token is whitelisted.
     * - Pool.sol: Increases the user's token supply in the pool.
     * - ChainContract.sol: Stakes the tokens with the specified validator.
     */
    function supply(address tokenType, uint256 amount, address validator) external whenNotPaused {
        _supply(msg.sender, tokenType, amount, validator);
    }
    

  
    /**
     * @dev Withdraws tokens from the pool and unstakes them from a validator.
     * @param tokenType The address of the token to withdraw.
     * @param amount The amount of tokens to withdraw.
     * @param validator The address of the validator to unstake from.
     *
     * This function performs the following steps:
     * 1. Updates the reward for the caller using the Reward contract.
     * 2. Calculates the maximum withdrawable amount for the user and token type.
     * 3. Ensures the requested amount doesn't exceed the maximum withdrawable amount.
     * 4. Calls the internal _decreaseAndUnstake function, which:
     *    - Calls Pool.decreasePoolToken to reduce the user's supply in the pool.
     *    - Calls ChainContract.unstakeToken to unstake the tokens from the validator.
     * 5. Emits a DecreaseSupplyEvent to log the withdrawal.
     *
     *  This function interacts with:
     * - Pool.sol: Decreases the user's token supply in the pool.
     * - ChainContract.sol: Unstakes the tokens from the specified validator.
     */
    function withdraw(address tokenType, uint256 amount, address validator) external whenNotPaused {
        _withdraw(msg.sender, msg.sender, tokenType, amount, validator);
    }
    
    /**
     * @dev Borrows USD tokens from the pool.
     *
     * This function performs the following steps:
     * 1. Calls the `borrowUSD` function in the `Pool` contract to:
     *    - Increase the user's borrow amount by the specified amount
     *    - Increase the total borrow amount in the pool
     *    - Mint the specified amount of USD tokens to the caller's address
     * 2. Retrieves the user's collateral ratio by calling the `getUserCollateralRatio` function.
     * 3. Retrieves the system's Minimum Collateral Ratio (MCR) from the `Config` contract.
     * 4. Checks if the user's collateral ratio is greater than the system's MCR. If not, the transaction reverts with an error message.
     * 5. Emits the `IncreaseBorrowEvent` event to indicate the borrowing of USD tokens by the caller.
     *
     * @param amount The amount of USD tokens to borrow.
     */
    function borrow(uint256 amount) external whenNotPaused {
        _borrow(msg.sender, amount);
    }
    /**
     * @dev Repays borrowed USD tokens to the pool.
     * @param amount The amount of USD tokens to repay.
     * This function performs the following steps:
     * 1. Calls the repayUSD function in the Pool contract, which:
     *    - Checks if the repaid amount doesn't exceed the user's borrow amount
     *    - Decreases the user's borrow amount and the total borrow amount
     *    - Burns the repaid USD tokens from the repayer
     * 2. Emits a RepayEvent to log the repayment
     */
    function repay(uint256 amount) external whenNotPaused {
        _repay(msg.sender, amount);
    }

    /**
     * @dev Liquidates a user's position if their collateral ratio is below the liquidation rate.
     *
     * This function performs the following steps:
     * 1. Checks if the liquidator is not the same as the user being liquidated.
     * 2. Retrieves the user's collateral ratio by calling the `getUserCollateralRatio` function.
     * 3. Retrieves the system's liquidation rate from the `Config` contract.
     * 4. Checks if the user's collateral ratio is less than or equal to the system's liquidation rate.
     *    If not, the transaction reverts with an error message.
     * 5. Updates the rewards for the liquidated user and the liquidator by calling the `updateReward` function.
     * 6. Retrieves the total borrow amount of the liquidated user from the `Pool` contract.
     * 7. Repays the borrowed USD tokens on behalf of the liquidated user by calling the `repayUSD` function in the `Pool` contract.
     * 8. Liquidates the user's tokens by calling the `liquidateTokens` function in the `Pool` contract.
     *    - The `liquidateTokens` function iterates through all whitelisted tokens, and for each token:
     *      - If the liquidated user has a supply greater than 0 for that token, it transfers the entire amount to the liquidator.
     *      - Emits a `LiquidateToken` event, recording the details of the token liquidation.
     * 9. Liquidates the user's staked positions by calling the `liquidatePosition` function in the `ChainContract`.
     *    - The `liquidatePosition` function iterates through all validators, and for each validator:
     *      - Iterates through all whitelisted tokens, and for each token:
     *        - If the liquidated user has a stake amount greater than 0 for that validator and token, it transfers the entire amount to the liquidator.
     *        - Emits a `ChainLiquidateEvent` event, recording the details of the position liquidation.
     * 10. Emits the `LiquidateEvent` event to indicate the liquidation of the user's position.
     *
     * @param liquidatedUser The address of the user whose position is being liquidated.
     */
    function liquidate(address liquidatedUser) external whenNotPaused {
        require(msg.sender != liquidatedUser, "Lend: Invalid liquidator");
        uint256 userCollateralRatio = getUserCollateralRatio(liquidatedUser);
        uint256 systemLiquidateRate = config.liquidationRate();
        require(systemLiquidateRate >= userCollateralRatio, "Lend: Larger than liquidation rate");

        reward.updateReward(liquidatedUser);
        reward.updateReward(msg.sender);

        uint256 repayAmount = pool.getUserTotalBorrow(liquidatedUser);
        pool.repayUSD(msg.sender, liquidatedUser, repayAmount);
        pool.liquidateTokens(liquidatedUser, msg.sender);
        chain.liquidatePosition(msg.sender, liquidatedUser);
        emit LiquidateEvent(msg.sender, liquidatedUser, repayAmount);
    }

    /**
     * @dev Migrates staked tokens from a deleted validator to a new validator.
     * 
     * This function performs the following steps:
     * 1. Checks if the deleted validator is a valid validator.
     * 2. Gets the migrate stake limit from the ChainContract.
     * 3. Retrieves the staked users for the deleted validator.
     * 4. Determines the number of users to migrate based on the migrate stake limit.
     * 5. Updates the rewards for the users being migrated.
     * 6. Calls the migrateStakes function in the ChainContract to perform the actual migration.
     *
     * The migrateStakes function in the ChainContract does the following:
     * 1. Adds the new validator to the list of validators if it's not already present.
     * 2. If the deleteAmount is 0, removes the deleted validator from the list of validators.
     * 3. For each user being migrated (up to the deleteAmount):
     *    - For each whitelisted token:
     *      - Transfers the user's stake from the deleted validator to the new validator.
     *      - Updates the total stake for the deleted and new validators.
     *    - Removes the user from the deleted validator's staked users list.
     *    - Adds the user to the new validator's staked users list.
     * 4. If the deleted validator has no more staked users, removes it from the list of validators.
     *
     * The migrateStakeLimit is used to prevent the case where a validator has too many staked users.
     * In such cases, this function may need to be called multiple times to migrate all the users.
     *
     * @param deletedValidator The address of the deleted validator.
     * @param newValidator The address of the new validator.
     **/
    function migrateStakes(address deletedValidator, address newValidator) external onlyOwner whenNotPaused {
        require(chain.containsValidator(deletedValidator), "Lend: Invalid validator");
        uint256 migrateStakeLimit = chain.getMigrateStakeLimit();

        address[] memory validatorStakedUsers = chain.getValidatorStakedUsers(deletedValidator);
        uint256 deleteAmount = validatorStakedUsers.length <= migrateStakeLimit ? validatorStakedUsers.length : migrateStakeLimit;
        
        for (uint256 i = 0; i < deleteAmount; i++) {
            address userAddress = validatorStakedUsers[i];
            reward.updateReward(userAddress);
        }
        
        chain.migrateStakes(deletedValidator, newValidator, deleteAmount);
    }

    /**
     * @dev Calculates the maximum amount of a token that a user can withdraw.
     * @param user The address of the user.
     * @param tokenType The address of the token.
     * @return The maximum amount of the token that the user can withdraw.
     */
    function getTokenMaxWithdrawable(address user, address tokenType) public view returns (uint256) {
        uint256 borrowUSD = getUserBorrowTotalUSD(user);
        uint256 mcr = config.getMCR();
        uint256 precisionDecimals = config.getPrecision();
        uint256 precision = 10 ** precisionDecimals;
        uint256 minCollateralUSDValue = mcr * borrowUSD / precision;
        uint256 tokenPrice = getTokenPrice(tokenType);
        uint256 tokenDecimals = config.getTokenDecimals(tokenType);                            
        uint256 minCollateralAmount = minCollateralUSDValue * 10 ** tokenDecimals / tokenPrice;
        uint256 userSupplyAmount = pool.getUserTokenSupply(user, tokenType);
        if (minCollateralAmount > userSupplyAmount) {
            return 0;
        }
        return userSupplyAmount - minCollateralAmount;
    }

    /**
     * @dev Calculates the maximum amount of USD a user can borrow.
     * @param user The address of the user.
     * @return The maximum amount of USD the user can borrow.
     */
    function getUserMaxBorrowable(address user) public view returns (uint256) {
        uint256 supplyUSD = getUserSupplyTotalUSD(user);
        uint256 mcr = config.getMCR();
        uint256 precisionDecimals = config.getPrecision();
        uint256 precision = 10 ** precisionDecimals;
        uint256 maxBorrowUSDValue = supplyUSD * precision / mcr;
        uint256 currentBorrowUSDValue = getUserBorrowTotalUSD(user);
        if (currentBorrowUSDValue >= maxBorrowUSDValue) {
            return 0;
        }
        uint256 maxBorrowUSD = (maxBorrowUSDValue - currentBorrowUSDValue) * 10 ** usd.decimals() / precision;
        return maxBorrowUSD;
    }

    /**
     * @dev Calculates a user's collateral ratio.
     * Return value equal to getUserSupplyTotalUSD(user) * precision / getUserBorrowTotalUSD(user)
     * @param user The address of the user.
     * @return The user's collateral ratio.
     */
    function getUserCollateralRatio(address user) public view returns (uint256) {
        uint256 precisionDecimals = config.getPrecision();
        uint256 precision = 10 ** precisionDecimals;
        if (getUserBorrowTotalUSD(user) == 0 && getUserSupplyTotalUSD(user) != 0) {
            return type(uint256).max;
        }
        return getUserSupplyTotalUSD(user) * precision / getUserBorrowTotalUSD(user);
    }

    /**
     * @dev Calculates the total USD value of a user's supplied tokens.
     * Return value equal to sum(userTokenSupply * tokenPrice) / 10 ** tokenDecimals
     * @param user The address of the user.
     * @return The total USD value of the user's supplied tokens.
     */
    function getUserSupplyTotalUSD(address user) public view returns (uint256) {
        address[] memory whitelistTokens = config.getAllWhitelistTokens();
        uint256 usdValue = 0;
        for (uint256 i = 0; i < whitelistTokens.length; i++) {
            address tokenAddress = whitelistTokens[i];
            uint256 userTokenSupply = pool.getUserTokenSupply(user, tokenAddress);
            uint256 price = getTokenPrice(tokenAddress);
            uint256 tokenDecimals = config.getTokenDecimals(tokenAddress);            
            usdValue += userTokenSupply * price / (10 ** tokenDecimals);
        }
        return usdValue;
    }

    /**
     * @dev Calculates the total USD value of a user's borrowed tokens. 
     * Return value equal to userTokenBorrow * 10 ** systemPriceDecimals / 10 ** usdDecimals
     * @param user The address of the user.
     * @return The total USD value of the user's borrowed tokens.
     */
    function getUserBorrowTotalUSD(address user) public view returns (uint256) {
        uint256 userTokenBorrow = pool.getUserTotalBorrow(user);
        uint256 usdDecimals = usd.decimals();
        uint256 systemPriceDecimals = config.getPrecision();
        return userTokenBorrow * 10 ** systemPriceDecimals / 10 ** usdDecimals;
    }

    /**
     * @dev Gets the price of a token in USD.
     * @param tokenType The address of the token.
     * @return The price of the token in USD.
     */
    function getTokenPrice(address tokenType) public view returns (uint256) {
        uint256 price = priceFeed.latestAnswer(tokenType);
        uint256 decimals = priceFeed.getPriceDecimals();
        uint256 systemDecimals = config.getPrecision();
        if (systemDecimals > decimals) {
            price = price * (10 ** (systemDecimals - decimals));
        } else {
            price = price / (10 ** (decimals - systemDecimals));
        }
        return price;
    }

    function _supply(address user, address tokenType, uint256 amount, address validator) internal {
        reward.updateReward(user);
        require(config.isWhitelistToken(tokenType), "Lend: Not whitelisted token");
        IERC20(tokenType).safeTransferFrom(msg.sender, address(pool), amount);
        _increaseAndStake(user, tokenType, amount, validator);
        emit IncreaseSupplyEvent(user, tokenType, amount, validator);
    }

    function _withdraw(address user, address receiver, address tokenType, uint256 amount, address validator) internal {
        reward.updateReward(user);
        uint256 maxWithdrawable = getTokenMaxWithdrawable(user, tokenType);
        require(amount <= maxWithdrawable, "Lend: Exceed withdraw amount");
        _decreaseAndUnstake(user, receiver, tokenType, amount, validator);
        emit DecreaseSupplyEvent(user, tokenType, amount, validator);
    }


    function _borrow(address user, uint256 amount) internal {
        pool.borrowUSD(user, amount);
        uint256 userCollateralRatio = getUserCollateralRatio(user);
        uint256 systemMCR = config.getMCR();
        require(userCollateralRatio > systemMCR, "Lend: Lower than MCR");
        emit IncreaseBorrowEvent(user, amount);
    }

    function _repay(address user, uint256 amount) internal {
        pool.repayUSD(user, user, amount);
        emit RepayEvent(user, amount);
    }
    



    /**
     * @dev Increases a user's token supply and stakes the tokens with a validator.
     * @param user The address of the user.
     * @param tokenType The address of the token.
     * @param amount The amount of tokens to increase and stake.
     * @param validator The address of the validator to stake with.
     */
    function _increaseAndStake(address user, address tokenType, uint256 amount, address validator) internal {
        pool.increasePoolToken(user, tokenType, amount);
        chain.stakeToken(user, validator, tokenType, amount);
    }

    /**
     * @dev Decreases a user's token supply and unstakes the tokens from a validator.
     * @param user The address of the user.
     * @param receiver The address of the receiver.
     * @param tokenType The address of the token.
     * @param amount The amount of tokens to decrease and unstake.
     * @param validator The address of the validator to unstake from.
     */
    function _decreaseAndUnstake(address user, address receiver, address tokenType, uint256 amount, address validator) internal {
        pool.decreasePoolToken(user, receiver, tokenType, amount);
        chain.unstakeToken(user, validator, tokenType, amount);
    }
}
