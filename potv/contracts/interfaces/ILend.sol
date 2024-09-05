// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILend {
    function supply(address tokenType, uint256 amount, address validator) external;
    function withdraw(address tokenType, uint256 amount, address validator) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function liquidate(address liquidatedUser) external;
    function migrateStakes(address deletedValidator, address newValidator) external;
    function pluginSupply(address user, address tokenType, uint256 amount, address validator) external;
    function pluginWithdraw(address user, address tokenType, uint256 amount, address validator) external;
}
