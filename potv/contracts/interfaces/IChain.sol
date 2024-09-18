// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IChain {
    function setValidators(address[] memory newValidators) external;
    function stakeToken(address validator, address tokenType, uint256 amount) external;
    function unstakeToken(address validator, address tokenType, uint256 amount) external;
    function migrateStakes(address deletedValidator, address newValidator) external;
    function getValidators() external view returns (address[] memory);
    function getValidatorTokenStake(address validator, address tokenType) external view returns (uint256);
    function getMigrateStakeLimit() external pure returns (uint256);
    function containsValidator(address validator) external view returns (bool);

    event ChainMigrateEvent(
        address indexed deletedValidator,
        address indexed newValidator,
        address tokenType,
        uint256 stakeAmount
    );

    event StakeTokenEvent(
        address indexed validator,
        address tokenType,
        uint256 amount
    );

    event UnstakeTokenEvent(
        address indexed validator,
        address tokenType,
        uint256 amount
    );
}
