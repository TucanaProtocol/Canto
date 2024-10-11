interface IPriceFeed {
    function setTokenPrices(address[] memory tokens, int256[] memory prices) external;
    function latestAnswer(address token) external view returns (uint256);
    function latestUpdateTime(address token) external view returns (uint256);
    function getPriceDecimals() external view returns (uint256);
}
