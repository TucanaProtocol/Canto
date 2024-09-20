import { ethers } from "hardhat";
import * as fs from 'fs';
import ContractAdds from "../deployed-addresses.json"
import config from "../config.json"

async function main() {
    const collateral_1 = await ethers.getContractAt("MockToken", ContractAdds.Collateral_1);
    const configContract = await ethers.getContractAt("Config", ContractAdds.Config);
    console.log(await configContract.isWhitelistToken(ContractAdds.Collateral_1));
    const approve = await collateral_1.approve(ContractAdds.Lend, ethers.MaxUint256);
    await approve.wait();


    const validator1 = config.validators[0];
    const lend = await ethers.getContractAt("Lend", ContractAdds.Lend);
    const tx = await lend.supply(ContractAdds.Collateral_1, ethers.parseEther('10'), validator1);
    await tx.wait();
    console.log("Supply successful", tx.hash);
    
    

  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
