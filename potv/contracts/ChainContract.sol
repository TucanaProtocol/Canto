// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IChain.sol";

contract ChainContract is Initializable, OwnableUpgradeable, IChain {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant PRECISION_DECIMALS = 6;
    uint256 public constant MIGRATE_STAKE_LIMIT = 500;

    IConfig public config;
    address public lendContract;

    EnumerableSet.AddressSet private validators;
    mapping(address => mapping(address => uint256)) private validatorStakes;


    function initialize(address _configAddress) public initializer {
        __Ownable_init();
        config = IConfig(_configAddress);
    }

    modifier onlyLend() {
        require(msg.sender == lendContract, "ChainContract: Only Lend contract can call this function");
        _;
    }

    function setLendContract(address _lendContract) external onlyOwner {
        lendContract = _lendContract;
    }

    function setValidators(address[] memory newValidators) external onlyOwner {
        for (uint256 i = 0; i < validators.length(); i++) {
            validators.remove(validators.at(i));
        }
        for (uint256 i = 0; i < newValidators.length; i++) {
            validators.add(newValidators[i]);
        }
    }

    function stakeToken( address validator, address tokenType, uint256 amount) external onlyLend {
        require(validators.contains(validator), "ChainContract: Invalid validator");
        _stakeToken(validator, tokenType, amount);
    }

    function _stakeToken( address validator, address tokenType, uint256 amount) internal {

        validatorStakes[validator][tokenType] += amount;
        emit StakeTokenEvent(validator, tokenType, amount);
    }


    function unstakeToken(address validator, address tokenType, uint256 amount) external onlyLend {
        require(validatorStakes[validator][tokenType] >= amount, "ChainContract: Insufficient stake");
        _unstakeToken(validator, tokenType, amount);
    }


    function _unstakeToken( address validator, address tokenType, uint256 amount) internal {
        validatorStakes[validator][tokenType] -= amount;
        emit UnstakeTokenEvent(validator, tokenType, amount);
    }

   
    function migrateStakes(address deletedValidator, address newValidator) external onlyLend {
        if (!validators.contains(newValidator)) {
            validators.add(newValidator);
        }
       
        address[] memory whitelistTokens = config.getAllWhitelistTokens();

    
            for (uint256 j = 0; j < whitelistTokens.length; j++) {
                address tokenType = whitelistTokens[j];
                uint256 stakeAmount = validatorStakes[deletedValidator][tokenType];
                if (stakeAmount > 0) {
                    _unstakeToken(deletedValidator, tokenType, stakeAmount);
                    _stakeToken(newValidator, tokenType, stakeAmount);
                    emit ChainMigrateEvent(deletedValidator, newValidator, tokenType, stakeAmount);
                }
            }
       
    }

    function getValidators() external view returns (address[] memory) {
        return validators.values();
    }

    function containsValidator(address validator) external view returns (bool) {
        return validators.contains(validator);
    }

   

    function getValidatorTokenStake(address validator, address tokenType) external view returns (uint256) {
        return validatorStakes[validator][tokenType];
    }

    function getMigrateStakeLimit() external pure returns (uint256) {
        return MIGRATE_STAKE_LIMIT;
    }
}
