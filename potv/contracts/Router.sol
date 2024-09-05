// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./interfaces/ILend.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

//TODO
import "./test/TestSwapRouter.sol";
contract Router is Initializable {
     ILend public lend;
     TestSwapRouter public testSwapRouter;
     function initialize(
        address _lendAddress,
        address _testSwapRouterAddress

    ) public initializer {
        lend = ILend(_lendAddress);
        testSwapRouter = TestSwapRouter(_testSwapRouterAddress);
    }
    function swapAndSupply(address _fromToken, uint256 _amount, address validator) external {
        // Swap tokens
        IERC20Upgradeable(_fromToken).transferFrom(msg.sender, address(this), _amount);

        IERC20Upgradeable(_fromToken).approve(address(testSwapRouter), _amount);
        uint256 swappedAmount = testSwapRouter.swap(_fromToken, _amount);
        // Supply tokens
        IERC20Upgradeable(address(testSwapRouter)).approve(address(lend), swappedAmount);
        
        lend.pluginSupply(msg.sender, address(testSwapRouter), swappedAmount, validator);

    }

    function withdrawAndSwap(address _token, uint256 _amount, address validator) external {
        // Withdraw tokens
        lend.pluginWithdraw(msg.sender, _token, _amount, validator);
        // Swap tokens
        testSwapRouter.approve(_token, _amount);
    }
}
