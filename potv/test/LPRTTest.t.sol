// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/Config.sol";
import "../contracts/PriceFeed.sol";
import "../contracts/ChainContract.sol";
import "../contracts/Pool.sol";
import "../contracts/Reward.sol";
import "../contracts/Lend.sol";
import "../contracts/TUCUSD.sol";
import "../contracts/test/MockToken.sol";
import "../contracts/LPRT.sol";
import "../contracts/StakeModule.sol";
import "../contracts/StakePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";




contract LPRTTest is Test {
    Config public config;
    PriceFeed public priceFeed;
    ChainContract public chainContract;
    Pool public pool;
    Reward public reward;
    Lend public lend;
    TUCUSD public usd;
    StakeModule public stakeModule;
    StakePool public stakePool;
    MockToken public collateral1;
    MockToken public collateral2;
    MockToken public fakeCollateral;
    MockToken public rewardToken;
    MockToken public rewardToken2;

    address public owner;
    address public user1;
    address public user2;
    address[] public validators;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        validators = new address[](2);
        validators[0] = address(0x3);
        validators[1] = address(0x4);
        vm.startPrank(owner);   
        // Deploy contracts
        config = new Config();
        config.initialize(1500000, 1100000);
        
        chainContract = new ChainContract();
        chainContract.initialize(address(config));
        
        priceFeed = new PriceFeed();
        priceFeed.initialize();
        
        pool = new Pool();
        pool.initialize(address(config));
        
        usd = new TUCUSD();
        usd.initialize(address(pool));
        
        reward = new Reward();

        stakeModule = new StakeModule();
        stakePool = new StakePool();

        stakeModule.initialize(address(config), address(chainContract), address(stakePool), address(reward));


        stakePool.initialize(address(stakeModule), address(config));

        
        reward.initialize(address(config), address(stakePool), address(stakeModule));
        
        lend = new Lend();
        lend.initialize(address(chainContract), address(pool), address(config), address(reward), address(priceFeed), address(usd));

        pool.setLendContract(address(lend));
        chainContract.setStakeModule(address(stakeModule));
        reward.setStakeModule(address(stakeModule));
        collateral1 = new MockToken();
        collateral2 = new MockToken();
        fakeCollateral = new MockToken();

        rewardToken = new MockToken();
        rewardToken2 = new MockToken();
        collateral1.mint(user1, 1000000 ether);
        collateral1.mint(user2, 1000000 ether);
        collateral2.mint(user1, 1000000 ether);
        collateral2.mint(user2, 1000000 ether);
        fakeCollateral.mint(user1, 1000000 ether);
        fakeCollateral.mint(user2, 1000000 ether);

        //set price
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(collateral1);
        tokenAddresses[1] = address(collateral2);
        uint256[] memory tokenPrices = new uint256[](2);
        tokenPrices[0] = 1000000;
        tokenPrices[1] = 1000000;
        priceFeed.setTokenPrices(tokenAddresses, tokenPrices);


        //add collateral
        config.addCollateral(address(collateral1));
        config.addCollateral(address(collateral2));

        //set validators
        chainContract.setValidators(validators);

        //set reward token
        reward.addRewardToken(address(rewardToken));
        reward.addRewardToken(address(rewardToken2));

        pool.setUsdAddress(address(usd));
        usd.setPool(address(pool));
        }

        function test_lprt() public {
        vm.startPrank(user1);
        collateral1.approve(address(stakeModule), 1 ether);
        stakeModule.stake(address(collateral1), validators[0], 1 ether);


        address lprtToken = stakeModule.lpTokenToLPRT(address(collateral1));
        uint256 userLprtBalance = IERC20(lprtToken).balanceOf(user1);
        console.log("userLprtBalance", userLprtBalance);

        vm.startPrank(owner);

        address[] memory rewardTokens = new address[](2);

        rewardTokens[0] = address(rewardToken);
        rewardTokens[1] = address(rewardToken2);
        
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = address(collateral1);

        uint256[][] memory rewardAmounts = new uint256[][](2);
        rewardAmounts[0] = new uint256[](1);
        rewardAmounts[0][0] = 1000 ether; // 1000 tokens as reward
        
        rewardAmounts[1] = new uint256[](1);
        rewardAmounts[1][0] = 1000 ether; // 1000 tokens as reward

        rewardToken.mint(owner, 1000 ether);
        rewardToken2.mint(owner, 1000 ether);
        rewardToken.approve(address(reward), 1000 ether);
        rewardToken2.approve(address(reward), 1000 ether);
        reward.distributeReward(rewardTokens, lpTokens, rewardAmounts);

        uint256 rewardPerTokenStored = reward.rewardPerTokenStored(address(rewardTokens[0]), address(collateral1));
        console.log("rewardPerTokenStored", rewardPerTokenStored);
        uint256 userReward = reward.earned(user1, address(rewardToken));
        console.log("userReward", userReward);

        vm.startPrank(user1);
        reward.claimReward( address(rewardToken));
        userReward = reward.earned(user1, address(rewardToken));
        console.log("userReward", userReward);



        }
    }