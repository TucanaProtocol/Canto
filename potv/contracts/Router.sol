// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./interfaces/ILend.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITucanaStableSwapLp.sol";
import "./interfaces/ITucanaStableSwapThreePool.sol";
import "./interfaces/ITucanaStableSwapTwoPool.sol";
import "./interfaces/ITucanaStableSwapPool.sol";


contract Router is Initializable {
     ILend public lend;

     function initialize(
        address _lendAddress
    ) public initializer {
        lend = ILend(_lendAddress);
    }

    function swapAndSupply(address _fromToken, address _lpToken, uint256 _amount, address validator) external {
        ITucanaStableSwapPool  swapPool = ITucanaStableSwapPool(ITucanaStableSwapLp(_lpToken).minter());
        uint256[] memory amounts = getAddLiquidityArray(_fromToken, swapPool, _amount);
        //transfer from user to router
        IERC20Upgradeable(_fromToken).transferFrom(msg.sender, address(this), _amount);
        IERC20Upgradeable(_fromToken).approve(address(swapPool), _amount);
    

        if(swapPool.N_COINS() == 2){
            uint256[2] memory fixedAmounts;
            for (uint256 i = 0; i < 2; i++) {
                fixedAmounts[i] = amounts[i];
            }
            ITucanaStableSwapTwoPool(address(swapPool)).add_liquidity(fixedAmounts, 0);
        }else{
            uint256[3] memory fixedAmounts;
            for (uint256 i = 0; i < 3; i++) {
                fixedAmounts[i] = amounts[i];
            }
            ITucanaStableSwapThreePool(address(swapPool)).add_liquidity(fixedAmounts, 0);
        }


        //supply to lend
        uint256 lpTokenAmount = IERC20Upgradeable(_lpToken).balanceOf(address(this));
        IERC20Upgradeable(_lpToken).approve(address(lend), lpTokenAmount);
        lend.pluginSupply(msg.sender, address(_lpToken), lpTokenAmount, validator);

    }

    function getTokenIndex(address _token, ITucanaStableSwapPool _swapPool) public view returns (uint256) {
        uint256 N_COINS = _swapPool.N_COINS();
        for (uint256 i = 0; i < N_COINS; i++) {
            if (_swapPool.coins(i) == _token) {
                return i;
            }
        }
    }

    function getAddLiquidityArray(address _token, ITucanaStableSwapPool _swapPool, uint256 _amount) public view returns (uint256[] memory) {
        uint256 tokenIndex = getTokenIndex(_token, _swapPool);
        uint256[] memory amounts = new uint256[](_swapPool.N_COINS());
        amounts[tokenIndex] = _amount;
        return amounts;
    }

  
}
