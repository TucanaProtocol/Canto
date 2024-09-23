// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/ITUCUSD.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IStakePool.sol";

contract StakePool is Initializable, OwnableUpgradeable, IStakePool {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IConfig public config;
    address public stakeModule;
    // lp address => amount
    mapping(address => uint256) public stakeAmount;


    modifier onlyStakeModule() {
        require(msg.sender == stakeModule, "StakePool: Only stake module can call this function");
        _;
    }

     function initialize(address _stakeModule, address _configAddress) public initializer {
        __Ownable_init();
        stakeModule = _stakeModule;   
        config = IConfig(_configAddress);
    }


     function stakeToStakePool(address _lpToken, uint256 _amount) external onlyStakeModule {
        require(config.isWhitelistToken(_lpToken), "Pool: Not a whitelisted token");
        stakeAmount[_lpToken] += _amount;
        emit StakeToStakePool(msg.sender, _lpToken, _amount);
     }

     function unstakeFromStakePool(address receiver, address _lpToken, uint256 _amount) external onlyStakeModule {
        require(stakeAmount[_lpToken] >= _amount, "Pool: Not enough staked amount");
        IERC20Upgradeable(_lpToken).safeTransfer(receiver, _amount);
        stakeAmount[_lpToken] -= _amount;
        emit UnstakeFromStakePool(msg.sender, receiver, _lpToken, _amount);
     }


}