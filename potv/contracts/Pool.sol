// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/ITUCUSD.sol";
import "./interfaces/IPool.sol";

contract Pool is Initializable, OwnableUpgradeable, IPool {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IConfig public config;
    ITUCUSD public usdToken;
    address public lendContract;
    
    mapping(address => uint256) public userBorrow;
    uint256 public totalBorrow;


    


    /// token address => user address => amount
    mapping(address => mapping(address => uint256)) public userSupply;
    mapping(address => uint256) public totalSupply;


    error NotWhiteListToken();
    error ExceedBorrowAmount();
    error ExceedSupplyAmount();
    error InsufficientSupply();
    error OnlyLendContract();



     modifier onlyLend() {
        require(msg.sender == lendContract, "Pool: Only Lend contract can call this function");
        _;
    }

    function initialize(address _configAddress) public initializer {
        __Ownable_init();
        config = IConfig(_configAddress);
    }

    function setUsdAddress(address _usdAddress) external onlyOwner {
        usdToken = ITUCUSD(_usdAddress);
    }

   
    function setLendContract(address _lendContract) external onlyOwner {
        lendContract = _lendContract;
    }

    function increasePoolToken(address user,address tokenAddress, uint256 amount) external onlyLend {
        require(config.isWhitelistToken(tokenAddress), "Pool: Not a whitelisted token");
        userSupply[tokenAddress][user] += amount;
        totalSupply[tokenAddress] += amount;

        emit IncreaseToken(user, tokenAddress, amount);
    }

    function decreasePoolToken(address user, address receiver, address tokenAddress, uint256 amount) external onlyLend {
        require(userSupply[tokenAddress][user] >= amount, "Pool: Insufficient balance");

        userSupply[tokenAddress][user] -= amount;
        totalSupply[tokenAddress] -= amount;

        IERC20Upgradeable(tokenAddress).safeTransfer(receiver, amount);

        emit DecreaseToken(user, tokenAddress, amount);
    }

    function liquidateTokens(address src, address dest) external onlyLend {
        address[] memory whitelistTokens = config.getAllWhitelistTokens();
        for (uint i = 0; i < whitelistTokens.length; i++) {
            address tokenAddress = whitelistTokens[i];
            uint256 srcBalance = userSupply[tokenAddress][src];
            if (srcBalance > 0) {
                userSupply[tokenAddress][src] = 0;
                userSupply[tokenAddress][dest] += srcBalance;
                emit LiquidateToken(dest, src, tokenAddress, srcBalance);
            }
        }
    }

    function borrowUSD(address user,uint256 amount) external onlyLend {
        userBorrow[user] += amount;
        totalBorrow += amount;
        usdToken.mint(user, amount);

        emit Borrow(user, amount);
    }

    function repayUSD(address repayer, address repaidUser, uint256 amount) external onlyLend {
        require(userBorrow[repaidUser] >= amount, "Pool: Exceed borrow amount");
        userBorrow[repaidUser] -= amount;
        totalBorrow -= amount;
        usdToken.burn(repayer, amount);
        emit Repay(repaidUser, amount);
    }

    function getUserTokenSupply(address user, address tokenType) external view returns (uint256) {
        return userSupply[tokenType][user];
    }

    function getUserTotalBorrow(address user) external view returns (uint256) {
        return userBorrow[user];
    }

    function getSystemTokenTotalSupply(address tokenType) external view returns (uint256) {
        return totalSupply[tokenType];
    }

    function getSystemTotalBorrowed() external view returns (uint256) {
        return totalBorrow;
    }
}
