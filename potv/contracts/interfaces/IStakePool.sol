// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;



interface IStakePool {

    function stakeToStakePool(address _lpToken, uint256 _amount) external;
    function unstakeFromStakePool(address _recipient, address _lpToken, uint256 _amount) external;

    event StakeToStakePool(address indexed user, address indexed lpToken, uint256 amount);
    event UnstakeFromStakePool(address indexed user, address indexed recipient, address indexed lpToken, uint256 amount);
}
