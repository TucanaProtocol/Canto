// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IChain.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IReward.sol";
import "./interfaces/IPriceFeed.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lend is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    IChain public chain;
    IPool public pool;
    IConfig public config;
    IReward public reward;
    IPriceFeed public priceFeed;
    IERC20Metadata public usd;

    event IncreaseSupplyEvent(address indexed account, address indexed tokenType, uint256 amount, address indexed validator);
    event IncreaseBorrowEvent(address indexed account, uint256 amount);
    event DecreaseSupplyEvent(address indexed account, address indexed tokenType, uint256 amount, address indexed validator);
    event RepayEvent(address indexed account, uint256 amount);
    event LiquidateEvent(address indexed liquidator, address indexed liquidatedUser, uint256 repayAmount);

    function initialize(
        address _chainAddress,
        address _poolAddress,
        address _configAddress,
        address _rewardAddress,
        address _priceFeedAddress,
        address _usdAddress
    ) public initializer {
        __Ownable_init();
        chain = IChain(_chainAddress);
        pool = IPool(_poolAddress);
        config = IConfig(_configAddress);
        reward = IReward(_rewardAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        usd = IERC20Metadata(_usdAddress);
    }

    function supply(address tokenType, uint256 amount, address validator) external {
        reward.updateReward(msg.sender);
        require(config.isWhitelistToken(tokenType), "Lend: Not whitelisted token");
        IERC20(tokenType).safeTransferFrom(msg.sender, address(pool), amount);
        _increaseAndStake(msg.sender, tokenType, amount, validator);
        emit IncreaseSupplyEvent(msg.sender, tokenType, amount, validator);
    }

    function withdraw(address tokenType, uint256 amount, address validator) external {
        reward.updateReward(msg.sender);
        uint256 maxWithdrawable = getTokenMaxWithdrawable(msg.sender, tokenType);
        require(amount <= maxWithdrawable, "Lend: Exceed withdraw amount");
        _decreaseAndUnstake(msg.sender, tokenType, amount, validator);
        emit DecreaseSupplyEvent(msg.sender, tokenType, amount, validator);
    }

    function borrow(uint256 amount) external {
        pool.borrowUSD(msg.sender, amount);
        uint256 userCollateralRatio = getUserCollateralRatio(msg.sender);
        uint256 systemMCR = config.getMCR();
        require(userCollateralRatio > systemMCR, "Lend: Lower than MCR");
        emit IncreaseBorrowEvent(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        pool.repayUSD(msg.sender, msg.sender, amount);
        emit RepayEvent(msg.sender, amount);
    }

    function liquidate(address liquidatedUser) external {
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

    function migrateStakes(address deletedValidator, address newValidator) external onlyOwner {
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

    function getUserCollateralRatio(address user) public view returns (uint256) {
        uint256 precisionDecimals = config.getPrecision();
        uint256 precision = 10 ** precisionDecimals;
        if (getUserBorrowTotalUSD(user) == 0 && getUserSupplyTotalUSD(user) != 0) {
            return type(uint256).max;
        }
        return getUserSupplyTotalUSD(user) * precision / getUserBorrowTotalUSD(user);
    }

    // supply value = usdvalue * 10 ** systemDecimals
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

    //borrow value = usdvalue * 10 ** systemDecimals
    function getUserBorrowTotalUSD(address user) public view returns (uint256) {
        uint256 userTokenBorrow = pool.getUserTotalBorrow(user);
        uint256 usdDecimals = usd.decimals();
        uint256 systemPriceDecimals = config.getPrecision();
        return userTokenBorrow * 10 ** systemPriceDecimals / 10 ** usdDecimals;
    }

    // price = usdValue * 10 ** systemDecimals 
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

    function _increaseAndStake(address user, address tokenType, uint256 amount, address validator) internal {
        pool.increasePoolToken(user, tokenType, amount);
        chain.stakeToken(user, validator, tokenType, amount);
    }

    function _decreaseAndUnstake(address user, address tokenType, uint256 amount, address validator) internal {
        pool.decreasePoolToken(user, tokenType, amount);
        chain.unstakeToken(user, validator, tokenType, amount);
    }
}
