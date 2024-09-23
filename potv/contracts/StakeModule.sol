// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IChain.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IReward.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/ILend.sol";
import "./interfaces/ITUCUSD.sol";
import "./interfaces/IStakePool.sol";
import "./interfaces/ILPRT.sol";
import "./LPRT.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
contract StakeModule is Initializable, OwnableUpgradeable, PausableUpgradeable {

        using SafeERC20 for IERC20;
        using EnumerableSet for EnumerableSet.AddressSet;
        IConfig public config;
        IChain public chain;      
        IStakePool public stakePool;
        IReward public reward;
        //lp address => lprt address
        mapping(address => address) public lpTokenToLPRT;
        // Set to store all LPRT addresses
        EnumerableSet.AddressSet private lprtTokens;

        function initialize(address _configAddress, address _chainAddress, address _stakePoolAddress, address _rewardAddress) public initializer {
            __Ownable_init();
            __Pausable_init();
            config = IConfig(_configAddress);
            chain = IChain(_chainAddress);
            stakePool = IStakePool(_stakePoolAddress);
            reward = IReward(_rewardAddress);
        }

        function stake(address _lpToken, address _validator, uint256 _amount) external {
            require(config.isWhitelistToken(_lpToken), "Pool: Not a whitelisted token");
            IERC20(_lpToken).safeTransferFrom(msg.sender, address(stakePool), _amount);
            stakePool.stakeToStakePool(_lpToken, _amount);
            chain.stakeToken(_validator, _lpToken, _amount);
            if(lpTokenToLPRT[_lpToken] == address(0)){
                LPRT lprt = new LPRT(_lpToken, address(this), address(reward));
                lpTokenToLPRT[_lpToken] = address(lprt);
                lprtTokens.add(address(lprt));
            }
            ILPRT(lpTokenToLPRT[_lpToken]).mint(msg.sender, _amount);
        }

        function unstake(address _lpToken, address _validator, uint256 _amount) external {
            require(lpTokenToLPRT[_lpToken] != address(0), "Pool: LPRT not found");
            ILPRT(lpTokenToLPRT[_lpToken]).burn(msg.sender, _amount);
            stakePool.unstakeFromStakePool(msg.sender, _lpToken, _amount);
            chain.unstakeToken(_validator, _lpToken, _amount);
        }

        function migrateValidator(address _validator, address _newValidator) external {
            chain.migrateStakes(_validator, _newValidator);
        }
        function containsLPRT(address _lprtToken) external view returns (bool) {
            return lprtTokens.contains(_lprtToken);
        }

    
   
}
