import { ethers, upgrades } from "hardhat";
import * as fs from 'fs';
import ContractAdds from "../deployed-addresses.json";
import config from "../config.json";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Upgrading Config contract with the account:", deployer.address);

  const Config = await ethers.getContractAt("Config", ContractAdds.Config);

  const beforeUpgradeMCR = await Config.getMCR();
  const UpgradeConfig = await ethers.getContractFactory("UpgradeConfig");
  
  console.log("Upgrading Config...");
  const upgradedConfig = await upgrades.upgradeProxy(ContractAdds.Config, UpgradeConfig);


  console.log("Config upgraded to:", upgradedConfig.address);
  

  //assert afterUpgradeMCR != beforeUpgradeMCR
  const afterUpgradeMCR = await Config.getMCR();
  console.log("Before upgrade MCR:", beforeUpgradeMCR);
  console.log("After upgrade MCR:", afterUpgradeMCR);



  const setMCR = await Config.setMCR(999);
  await setMCR.wait();
 
  const mcr = await Config.mcr();
  //assert mcr == 11111
  console.log(mcr);






}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
