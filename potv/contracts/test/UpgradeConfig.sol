// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/IConfig.sol";

contract UpgradeConfig is Initializable, OwnableUpgradeable, IConfig {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant PRECISION_DECIMALS = 6;

    EnumerableSet.AddressSet private _collateralTokens;
    uint256 public mcr;
    uint256 public liquidationRate;

    function initialize(uint256 _mcr, uint256 _liquidationRate) public initializer {
        __Ownable_init();
        mcr = _mcr;
        liquidationRate = _liquidationRate;
    }

    function addCollateral(address tokenType) external onlyOwner {
        require(!_collateralTokens.contains(tokenType), "Config: Collateral already exist");
        _collateralTokens.add(tokenType);
        emit CollateralAdded(tokenType);
    }

    function disableCollateral(address tokenType) external onlyOwner {
        require(_collateralTokens.contains(tokenType), "Config: Not collateral");
        _collateralTokens.remove(tokenType);
        emit CollateralDisabled(tokenType);
    }

    function setMCR(uint256 _mcr) external onlyOwner {
        mcr = 11111;
    }

    function setLiquidationRate(uint256 _liquidationRate) external onlyOwner {
        liquidationRate = _liquidationRate;
        emit LiquidationRateUpdated(_liquidationRate);
    }

    function getTokenDecimals(address tokenAddress) external view returns (uint256) {
        return IERC20Metadata(tokenAddress).decimals();
    }

    function isWhitelistToken(address tokenType) external view returns (bool) {
        return _collateralTokens.contains(tokenType);
    }

    function getAllWhitelistTokens() external view returns (address[] memory) {
        return _collateralTokens.values();
    }

    function getMCR() external view returns (uint256) {
        return 12345;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION_DECIMALS;
    }
}
