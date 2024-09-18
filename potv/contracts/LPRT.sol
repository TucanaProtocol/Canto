// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract LPRT is ERC20 {

    address public underlyingAsset;
    address public stakeModule;



    modifier onlyStakeModule() {
        require(msg.sender == stakeModule, "LPRT: Only stake module can call this function");
        _;
    }

    constructor(address _underlyingAsset, address _stakeModule) ERC20("LPRT", "LPRT") {
        underlyingAsset = _underlyingAsset;
        stakeModule = _stakeModule;
    }


    function mint(address to, uint256 amount) external onlyStakeModule {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyStakeModule {
        _burn(from, amount);
    }


   
}
