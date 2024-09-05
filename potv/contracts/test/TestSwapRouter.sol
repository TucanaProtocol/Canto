// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract TestSwapRouter is Initializable, ERC20Upgradeable {
    function initialize() public initializer {
        __ERC20_init("Test Swap Token", "TSWT");
        _mint(msg.sender, 100000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function swap(address token, uint256 amount) public returns (uint256) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        return amount;
    }


}
