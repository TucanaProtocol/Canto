// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILend {
    function supply(address tokenType, uint256 amount) external;
    function withdraw(address tokenType, uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function liquidate(address liquidatedUser) external;
}
