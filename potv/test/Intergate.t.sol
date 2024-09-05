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
    MockToken public fakeCollateral;
    MockToken public rewardToken;
    MockToken public rewardToken2;

    address public owner;
    address public user1;
    address public user2;
    address[] public validators;
    TestSwapRouter public testSwapRouter;
    Router public router;
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


        testSwapRouter = new TestSwapRouter();

        //set price
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(collateral1);
        tokenAddresses[1] = address(collateral2);
        tokenAddresses[2] = address(fakeCollateral);
        uint256[] memory tokenPrices = new uint256[](3);
        tokenPrices[0] = 1000000;
        tokenPrices[1] = 1000000;
        tokenPrices[2] = 1000000;
        priceFeed.setTokenPrices(tokenAddresses, tokenPrices);


        //add collateral
        config.addCollateral(address(collateral1));
        config.addCollateral(address(collateral2));
        config.addCollateral(address(testSwapRouter));
        //set validators
        chainContract.setValidators(validators);

        //set reward token
        reward.addRewardToken(address(rewardToken));
        reward.addRewardToken(address(rewardToken2));

        pool.setUsdAddress(address(usd));
        usd.setPool(address(pool));


    
        


        router = new Router();

        router.initialize(address(lend), address(testSwapRouter));

        lend.setPlugin(address(router), true);
        
    }

    function test_swapAndSupply() public {
        vm.startPrank(user1);

        collateral1.approve(address(router), 1 ether);
        router.swapAndSupply(address(collateral1), 1 ether, validators[0]);

        assertEq(pool.totalSupply(address(testSwapRouter)), 1 ether);
        assertEq(pool.userSupply(address(testSwapRouter), user1), 1 ether);

    }


}
