// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITucanaStableSwapThreePool {
  
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external payable;

    function remove_liquidity(uint256 _amount, uint256[3] memory min_amounts) external;

    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 max_burn_amount) external;
}
