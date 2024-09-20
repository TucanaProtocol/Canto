// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITucanaStableSwapPool {


    function N_COINS() external view returns (uint256);



    function coins(uint256 i) external view returns (address);

}
