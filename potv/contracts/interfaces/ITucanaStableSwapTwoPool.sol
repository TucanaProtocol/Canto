// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITucanaStableSwapTwoPool {
  
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable;

    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external;

    function remove_liquidity_imbalance(uint256[2] memory amounts, uint256 max_burn_amount) external;
}
