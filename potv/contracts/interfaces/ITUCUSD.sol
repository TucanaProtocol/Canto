// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITUCUSD {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function setPool(address _poolAddress) external;
}






