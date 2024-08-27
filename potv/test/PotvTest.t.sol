// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/Config.sol";
import "../contracts/PriceFeed.sol";
import "../contracts/ChainContract.sol";
import "../contracts/Pool.sol";
import "../contracts/Reward.sol";
import "../contracts/Lend.sol";
import "../contracts/USD.sol";
import "../contracts/test/MockToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";




contract PotvTest is Test {
    Config public config;
    PriceFeed public priceFeed;
    ChainContract public chainContract;
    Pool public pool;
    Reward public reward;
    Lend public lend;
    USD public usd;
    MockToken public collateral1;
    MockToken public collateral2;
    MockToken public rewardToken;

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
        
        usd = new USD();
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
        rewardToken = new MockToken();
        collateral1.mint(user1, 1000000 ether);
        collateral1.mint(user2, 1000000 ether);

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

        pool.setUsdAddress(address(usd));
        usd.setPool(address(pool));
    }

    function testSupplyToExistValidator() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        uint256 beforePoolBalance = collateral1.balanceOf(address(pool));
        uint256 beforeUserBalance = collateral1.balanceOf(user1);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        uint256 afterPoolBalance = collateral1.balanceOf(address(pool));
        uint256 afterUserBalance = collateral1.balanceOf(user1);
        assertEq(beforePoolBalance + 100 ether, afterPoolBalance);
        assertEq(beforeUserBalance - 100 ether, afterUserBalance);

        assertEq(chainContract.getUserValidatorTokenStake(user1, address(0x3), address(collateral1)), 100 ether);
    }

    function testFail_SupplyToNonExistValidator() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x5));
    }

    function testFail_Borrow_NotEnoughCollateral() public {
        vm.startPrank(user1);
        lend.borrow(1 ether);
    }


    function testFail_Borrow_LowerThanMCR() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(67 ether);
        
    }
   

    function test_borrow() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);
        assertEq(IERC20(address(usd)).balanceOf(user1), 60 ether);
        assertEq(lend.getUserBorrowTotalUSD(user1), 60 * 10 ** 6);
    }

    
    function test_repay() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);
        lend.repay(60 ether);
        assertEq(IERC20(address(usd)).balanceOf(user1), 0);
        assertEq(lend.getUserBorrowTotalUSD(user1), 0);
    }

    function testFail_repayUSDExceed() public {
         vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);
        lend.repay(61 ether);
    
    }

    function test_Withdraw() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.withdraw(address(collateral1), 10 ether, address(0x3));
        assertEq(collateral1.balanceOf(address(pool)), 90 ether);
        assertEq( pool.userSupply( address(collateral1), user1), 90 ether);
    }

    function test_withdrawWithBorrow() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);
        lend.withdraw(address(collateral1), 10 ether, address(0x3));
        assertEq(collateral1.balanceOf(address(pool)), 90 ether);
        assertEq( pool.userSupply( address(collateral1), user1), 90 ether);
        lend.repay(60 ether);
        lend.withdraw(address(collateral1), 90 ether, address(0x3));
          assertEq(collateral1.balanceOf(address(pool)), 0);
        assertEq( pool.userSupply( address(collateral1), user1), 0);
    }

    function test_liquidation() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);   
        vm.startPrank(user2);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);     


        vm.startPrank(owner);
        
        config.setLiquidationRate(2000000);

        //user 2 liquidate user 1
        vm.startPrank(user2);
        uint256 beforeUser2Supply = pool.userSupply(address(collateral1), user2);
        lend.liquidate( user1);

        //usd balance
        assertEq(IERC20(address(usd)).balanceOf(user2), 0);
        assertEq(IERC20(address(usd)).balanceOf(user1), 60 ether);
      

        //user supply
        assertEq(pool.userSupply(address(collateral1), user1), 0);
        assertEq(beforeUser2Supply + 100 ether, pool.userSupply(address(collateral1), user2));


        //user borrow
        assertEq(pool.userBorrow(user1), 0);
        assertEq(pool.userBorrow(user2), 60 ether);

        //validators
        assertEq(chainContract.getUserValidatorTokenStake(user1, address(0x3), address(collateral1)), 0);
        assertEq(chainContract.getUserValidatorTokenStake(user2, address(0x3), address(collateral1)), 200 ether);

    }

    function testFail_liquidate() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);   
        vm.startPrank(user2);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);     

        vm.startPrank(owner);
        
        //user 2 liquidate user 1
        vm.startPrank(user2);
        lend.liquidate( user1);
    }



    function testFail_MigrateFromNonExistValidator() public {
        vm.startPrank(user1);
       collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);   
        vm.startPrank(user2);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether); 
           
        vm.startPrank(owner);
        lend.migrateStakes( address(0x5), address(0x4));    
    }


    function test_migrateWithoutSupply() public {
        vm.startPrank(owner);
       lend.migrateStakes( address(0x3), address(0x5));    
    }

    function test_migrateToNonExistValidator() public {
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether);   
        vm.startPrank(user2);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        lend.borrow(60 ether); 
           
        vm.startPrank(owner);
        lend.migrateStakes( address(0x3), address(0x5));    

           //validators
        assertEq(chainContract.getUserValidatorTokenStake(user1, address(0x3), address(collateral1)), 0);
        assertEq(chainContract.getUserValidatorTokenStake(user2, address(0x3), address(collateral1)), 0 );


        assertEq(chainContract.getUserValidatorTokenStake(user1, address(0x5), address(collateral1)), 100 ether);
        assertEq(chainContract.getUserValidatorTokenStake(user2, address(0x5), address(collateral1)), 100 ether );


        assertEq(chainContract.containsValidator(address(0x3)), false);
        assertEq(chainContract.containsValidator(address(0x5)), true);


        
    }
    function test_rewardDistribution() public {
        // Setup initial stakes for users
        vm.startPrank(user1);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        
        vm.startPrank(user2);
        collateral1.approve(address(lend), 10000 ether);
        lend.supply(address(collateral1), 100 ether, address(0x3));
        
        // Prepare reward distribution parameters
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(rewardToken);
        
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = address(collateral1);
        
        uint256[][] memory rewardAmounts = new uint256[][](1);
        rewardAmounts[0] = new uint256[](1);
        rewardAmounts[0][0] = 1000 ether; // 1000 tokens as reward
        
        assertEq(reward.claimableReward(user1, address(rewardToken)), 0);
        assertEq(reward.claimableReward(user2, address(rewardToken)), 0);
        
        // Distribute rewards
        vm.startPrank(owner);
        rewardToken.mint(owner, 1000 ether);
        rewardToken.approve(address(reward), 1000 ether);
        reward.distributeReward(rewardTokens, lpTokens, rewardAmounts);
        assertEq(reward.claimableReward(user1, address(rewardToken)), 500 ether);
        assertEq(reward.claimableReward(user2, address(rewardToken)), 500 ether); 
  
        // Users claim their rewards
        vm.startPrank(user1);
        reward.claimReward(address(rewardToken));
        
        vm.startPrank(user2);
        reward.claimReward(address(rewardToken));
        
        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(user1), 500 ether);
        assertEq(rewardToken.balanceOf(user2), 500 ether);
        
        // Verify claimable rewards are now zero
        assertEq(reward.claimableReward(user1, address(rewardToken)), 0, "User1 should have no claimable rewards left");
        assertEq(reward.claimableReward(user2, address(rewardToken)), 0, "User2 should have no claimable rewards left");
    }
}
