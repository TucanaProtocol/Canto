// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;



interface IPool {

    
    function userBorrow(address) external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    
    function userSupply(address, address) external view returns (uint256);
    function totalSupply(address) external view returns (uint256);

    function increasePoolToken(address user,address tokenAddress, uint256 amount) external;
    function decreasePoolToken(address user, address receiver, address tokenAddress, uint256 amount) external;
    function liquidateTokens(address src, address dest) external;
    function borrowUSD(address user, uint256 amount) external;
    function repayUSD(address repayer, address repaidUser, uint256 amount) external;
    
    function getUserTokenSupply(address user, address tokenType) external view returns (uint256);
    function getUserTotalBorrow(address user) external view returns (uint256);
    function getSystemTokenTotalSupply(address tokenType) external view returns (uint256);
    function getSystemTotalBorrowed() external view returns (uint256);

    event Borrow(address indexed account, uint256 amount);
    event Repay(address indexed account, uint256 amount);
    event IncreaseToken(address indexed account, address indexed tokenType, uint256 amount);
    event DecreaseToken(address indexed account, address indexed tokenType, uint256 amount);
    event LiquidateToken(address indexed liquidator, address indexed liquidatedUser, address indexed tokenType, uint256 amount);
}
