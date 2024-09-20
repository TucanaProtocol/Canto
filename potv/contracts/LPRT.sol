// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IReward.sol";
contract LPRT is ERC20 {

    address public underlyingAsset;
    address public stakeModule;
    IReward public reward;




    modifier onlyStakeModule() {
        require(msg.sender == stakeModule, "LPRT: Only stake module can call this function");
        _;
    }

    constructor(address _underlyingAsset, address _stakeModule, address _reward) ERC20("LPRT", "LPRT") {
        underlyingAsset = _underlyingAsset;
        stakeModule = _stakeModule;
        reward = IReward(_reward);
    }



    function mint(address to, uint256 amount) external onlyStakeModule {
        _mint(to, amount);
    }



    function burn(address from, uint256 amount) external onlyStakeModule {
        _burn(from, amount);
    }



    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        uint256 fromBalance = balanceOf(from);
        uint256 toBalance = balanceOf(to);
        reward.handleAction(from, fromBalance);
        reward.handleAction(to, toBalance);
    }
}
