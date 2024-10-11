// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IConfig {
    function addCollateral(address tokenType) external;
    function disableCollateral(address tokenType) external;
    function setMCR(uint256 _mcr) external;
    function setLiquidationRate(uint256 _liquidationRate) external;
    function getTokenDecimals(address tokenAddress) external view returns (uint256);
    function isWhitelistToken(address tokenType) external view returns (bool);
    function getAllWhitelistTokens() external view returns (address[] memory);
    function getMCR() external view returns (uint256);
    function getPrecision() external pure returns (uint256);
    function liquidationRate() external view returns (uint256);
    event CollateralAdded(address token);
    event CollateralDisabled(address token);
    event MCRUpdated(uint256 newMCR);
    event LiquidationRateUpdated(uint256 newLiquidationRate);
}
