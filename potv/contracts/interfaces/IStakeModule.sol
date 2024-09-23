// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;



interface IStakeModule {



        function containsLPRT(address _lprtToken) external view returns (bool);
        function lpTokenToLPRT(address _lpToken) external view returns (address);
        


}
