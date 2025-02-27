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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/Router.sol";
import "../contracts/test/TestSwapRouter.sol";

contract Intergate is Test {
    Config public config;
    PriceFeed public priceFeed;
    ChainContract public chainContract;
    Pool public pool;
    Reward public reward;
    Lend public lend;
    TUCUSD public usd;
    MockToken public collateral1;
    MockToken public collateral2;
    MockToken public lpCollateral;
    MockToken public fakeCollateral;
    MockToken public rewardToken;
    MockToken public rewardToken2;



    MockToken public BUSD;
    MockToken public USDT;
    MockToken public USDC;

    address public owner;
    address public user1;
    address public user2;
    address[] public validators;

    Router public router;
    function setUp() public {
        BUSD = MockToken(0xFb20C17FB27CCe807FbCF045ceAd35fb76C883Ae);
        USDT = MockToken(0x3AE3e67E6DdA0bD1DdDe2c248Cd4e12542B27954);
        USDC = MockToken(0x34de463470f4611dF5b02245a6e96e3e3872058e);
        lpCollateral = MockToken(0x1fA3Fa83f450Cd4ACA24746F2A2103Ab40E84B46);

        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x330BD48140Cf1796e3795A6b374a673D7a4461d0);
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
        reward.initialize(address(config), address(pool));
        
        lend = new Lend();
        lend.initialize(address(chainContract), address(pool), address(config), address(reward), address(priceFeed), address(usd));

        pool.setLendContract(address(lend));
        chainContract.setLendContract(address(lend));
        reward.setLendContract(address(lend));
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
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(collateral1);
        tokenAddresses[1] = address(collateral2);
        tokenAddresses[2] = address(lpCollateral);
        uint256[] memory tokenPrices = new uint256[](3);
        tokenPrices[0] = 1000000;
        tokenPrices[1] = 1000000;
        tokenPrices[2] = 1000000;
        priceFeed.setTokenPrices(tokenAddresses, tokenPrices);


        //add collateral
        config.addCollateral(address(collateral1));
        config.addCollateral(address(collateral2));
        config.addCollateral(address(lpCollateral));
        //set validators
        chainContract.setValidators(validators);

        //set reward token
        reward.addRewardToken(address(rewardToken));
        reward.addRewardToken(address(rewardToken2));

        pool.setUsdAddress(address(usd));
        usd.setPool(address(pool));
        
        router = new Router();

        router.initialize(address(lend));

        lend.setPlugin(address(router), true);
        
    }

    function test_swapAndSupply() public {
        vm.startPrank(user2);

        BUSD.approve(address(router), 1 ether);
        uint256 beforePoolSupply = pool.totalSupply(address(lpCollateral));
        uint256 beforeUserSupply = pool.userSupply(address(lpCollateral), address(user2));
        assertEq(beforePoolSupply, 0);
        assertEq(beforeUserSupply, 0);
        router.swapAndSupply(address(BUSD), address(lpCollateral), 1 ether, validators[0]);
        uint256 afterPoolSupply = pool.totalSupply(address(lpCollateral));
        uint256 afterUserSupply = pool.userSupply(address(lpCollateral), address(user2));
        assertEq(afterPoolSupply > 0 , true);
        assertEq(afterUserSupply > 0 , true);
    }


    function test_withdrawAndDecreaseLiquidity() public {
        vm.startPrank(user2);

        BUSD.approve(address(router), 1 ether);
        router.swapAndSupply(address(BUSD), address(lpCollateral), 1 ether, validators[0]);
        

        uint256 beforePoolSupply = pool.totalSupply(address(lpCollateral));
        uint256 beforeUserSupply = pool.userSupply(address(lpCollateral), address(user2));
        uint256 usdtBalance = USDT.balanceOf(address(user2));

        router.withdrawAndDecreaseLiquidity(address(lpCollateral), 0.1 ether,  validators[0]);
        uint256 afterPoolSupply = pool.totalSupply(address(lpCollateral));
        uint256 afterUserSupply = pool.userSupply(address(lpCollateral), address(user2));
        uint256 afterUsdtBalance = USDT.balanceOf(address(user2));
        assertEq(afterPoolSupply < beforePoolSupply , true);
        assertEq(afterUserSupply < beforeUserSupply , true);
        assertEq(afterUsdtBalance > usdtBalance , true);

    }


    function test_swapAndSupplyWithReward() public {
       
        vm.startPrank(user2);
        BUSD.approve(address(router), 1 ether);
        router.swapAndSupply(address(BUSD), address(lpCollateral), 1 ether, validators[0]);
        



        //distribute reward
         // Setup reward distribution parameters
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(rewardToken);
        
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = address(lpCollateral);
        
        uint256[][] memory rewardAmounts = new uint256[][](1);
        rewardAmounts[0] = new uint256[](1);
        rewardAmounts[0][0] = 1000 ether; // 1000 tokens as reward
        
        // Distribute rewards
        vm.startPrank(owner);
        rewardToken.mint(owner, 1000 ether);
        rewardToken.approve(address(reward), 1000 ether);
        reward.distributeReward(rewardTokens, lpTokens, rewardAmounts);
        


        
        // Check claimable rewards
        assertEq(reward.claimableReward(user2, address(rewardToken)) > 0, true, "User2 should have claimable rewards");
        
        // User claims rewards
        vm.startPrank(user2);
        reward.claimReward(address(rewardToken));
        
        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(user2) > 0, true, "User2 should have received reward tokens");
    }
    
    function test_withdrawAndDecreaseLiquidityWithReward() public {
       
        
        vm.startPrank(user2);
        BUSD.approve(address(router), 1 ether);
        router.swapAndSupply(address(BUSD), address(lpCollateral), 1 ether, validators[0]);
        
         // Setup reward distribution parameters
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(rewardToken);
        
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = address(lpCollateral);
        
        uint256[][] memory rewardAmounts = new uint256[][](1);
        rewardAmounts[0] = new uint256[](1);
        rewardAmounts[0][0] = 1000 ether; // 1000 tokens as reward
        
        // Distribute rewards 
        vm.startPrank(owner);
        rewardToken.mint(owner, 1000 ether);
        rewardToken.approve(address(reward), 1000 ether);
        reward.distributeReward(rewardTokens, lpTokens, rewardAmounts);

        vm.startPrank(user2);
        // Withdraw and decrease liquidity
        router.withdrawAndDecreaseLiquidity(address(lpCollateral), 0.1 ether, validators[0]);
        
        // Check claimable rewards
        assertEq(reward.claimableReward(user2, address(rewardToken)) > 0, true, "User2 should have claimable rewards");
        
        // User claims rewards
        reward.claimReward(address(rewardToken));
        
        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(user2) > 0, true, "User2 should have received reward tokens");
    }

}
