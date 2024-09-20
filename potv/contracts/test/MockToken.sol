// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockToken is Initializable, ERC20Upgradeable {
    function initialize() public initializer {
        __ERC20_init("Mock Token", "Mock Token");
        _mint(msg.sender, 100000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
