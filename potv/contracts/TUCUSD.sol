// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IPool.sol";

contract TUCUSD is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    IPool public pool;

    function initialize(address _poolAddress) public initializer {
        __ERC20_init("TUCUSD", "TUCUSD");
        __Ownable_init();
        pool = IPool(_poolAddress);
    }

    function setPool(address _poolAddress) external onlyOwner {
        pool = IPool(_poolAddress);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == address(pool), "Only pool can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == address(pool), "Only pool can burn");
        _burn(from, amount);
    }
}
