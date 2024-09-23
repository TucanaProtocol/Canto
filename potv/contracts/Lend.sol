// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IChain.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IReward.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/ILend.sol";
import "./interfaces/IStakeModule.sol";
import "./interfaces/ILPRT.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lend is Initializable, OwnableUpgradeable, PausableUpgradeable, ILend {
    using SafeERC20 for IERC20;

    IPool public pool;
    IConfig public config;
    IReward public reward;
    IPriceFeed public priceFeed;
    IERC20Metadata public usd;
    IStakeModule public stakeModule;


    event IncreaseSupplyEvent(address indexed account, address indexed lprtAddress, uint256 amount);
    event IncreaseBorrowEvent(address indexed account, uint256 amount);
    event DecreaseSupplyEvent(address indexed account, address indexed lprtAddress, uint256 amount);
    event RepayEvent(address indexed account, uint256 amount);
    event LiquidateEvent(address indexed liquidator, address indexed liquidatedUser, uint256 repayAmount);


    /**
     * @dev Initializes the contrpluginSupplyact with the given addresses.
     * @param _poolAddress The address of the Pool contract.
     * @param _configAddress The address of the Config contract.
     * @param _rewardAddress The address of the Reward contract.
     * @param _priceFeedAddress The address of the PriceFeed contract.
     * @param _usdAddress The address of the USD token contract.
     */
    function initialize(
        address _poolAddress,
        address _configAddress,
        address _rewardAddress,
        address _priceFeedAddress,
        address _usdAddress,
        address _stakeModuleAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        pool = IPool(_poolAddress);
        config = IConfig(_configAddress);
        reward = IReward(_rewardAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        usd = IERC20Metadata(_usdAddress);
        stakeModule = IStakeModule(_stakeModuleAddress);

    }

   
    function supply(address lprtAddress, uint256 amount) external whenNotPaused {
        _supply(msg.sender, lprtAddress, amount);
    }
  
   
    function withdraw(address lprtAddress, uint256 amount) external whenNotPaused {
        _withdraw(msg.sender, msg.sender, lprtAddress, amount);
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
        emit LiquidateEvent(msg.sender, liquidatedUser, repayAmount);
    }


    /**
     * @dev Calculates the maximum amount of a lprt token that a user can withdraw.
     * @param user The address of the user.
     * @param lprtAddress The address of the token.
     * @return The maximum amount of the token that the user can withdraw.
     */
    function getTokenMaxWithdrawable(address user, address lprtAddress) public view returns (uint256) {
        uint256 borrowUSD = getUserBorrowTotalUSD(user);
        uint256 mcr = config.getMCR();
        uint256 precisionDecimals = config.getPrecision();
        uint256 precision = 10 ** precisionDecimals;
        uint256 minCollateralUSDValue = mcr * borrowUSD / precision;
        uint256 tokenPrice = getTokenPrice(lprtAddress);
        uint256 tokenDecimals = config.getTokenDecimals(lprtAddress);                            
        uint256 minCollateralAmount = minCollateralUSDValue * 10 ** tokenDecimals / tokenPrice;
        uint256 userSupplyAmount = pool.getUserTokenSupply(user, lprtAddress);
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
            address lpTokenAddress = whitelistTokens[i];
            address lprtAddress = stakeModule.lpTokenToLPRT(lpTokenAddress);
            uint256 userTokenSupply = pool.getUserTokenSupply(user, lprtAddress);
            uint256 price = getTokenPrice(lpTokenAddress);
            uint256 tokenDecimals = config.getTokenDecimals(lprtAddress);            
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
     * @dev Gets the price of a lp token in USD.
     * @param lpAddress The address of the token.
     * @return The price of the token in USD.
     */
    function getTokenPrice(address lpAddress) public view returns (uint256) {
        uint256 price = priceFeed.latestAnswer(lpAddress);
        uint256 decimals = priceFeed.getPriceDecimals();
        uint256 systemDecimals = config.getPrecision();
        if (systemDecimals > decimals) {
            price = price * (10 ** (systemDecimals - decimals));
        } else {
            price = price / (10 ** (decimals - systemDecimals));
        }
        return price;
    }

    function _supply(address user, address lprtAddress, uint256 amount) internal {
        address lpToken = ILPRT(lprtAddress).underlyingAsset();
        require(config.isWhitelistToken(lpToken), "Lend: Not whitelisted token");
        IERC20(lprtAddress).safeTransferFrom(msg.sender, address(pool), amount);
        _increaseAndStake(user, lprtAddress, amount);
        emit IncreaseSupplyEvent(user, lprtAddress, amount);
    }

    function _withdraw(address user, address receiver, address lprtAddress, uint256 amount) internal {
        uint256 maxWithdrawable = getTokenMaxWithdrawable(user, lprtAddress);
        require(amount <= maxWithdrawable, "Lend: Exceed withdraw amount");
        _decreaseAndUnstake(user, receiver, lprtAddress, amount);
        emit DecreaseSupplyEvent(user, lprtAddress, amount);
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
    



    function _increaseAndStake(address user, address tokenType, uint256 amount) internal {
        pool.increasePoolToken(user, tokenType, amount);
    }

  
    function _decreaseAndUnstake(address user, address receiver, address tokenType, uint256 amount) internal {
        pool.decreasePoolToken(user, receiver, tokenType, amount);
    }
}
