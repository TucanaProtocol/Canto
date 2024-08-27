import { ethers } from "hardhat";
import * as fs from 'fs';
import ContractAdds from "../deployed-addresses.json"
import config from "../config.json"


async function main() {
 
    //set price
    const priceFeed = await ethers.getContractAt("PriceFeed", ContractAdds.PriceFeed);
    const tokens = [ContractAdds.Collateral_1, ContractAdds.Collateral_2];
    const prices = [1000 * 10 ** 6, 1000 * 10 ** 6];
    const setPrice = await priceFeed.setTokenPrices(tokens, prices);
    await setPrice.wait();

    //add collateral
    const configContract = await ethers.getContractAt("Config", ContractAdds.Config);
    const addCollateral = await configContract.addCollateral(ContractAdds.Collateral_1)
    await addCollateral.wait();
    const addCollateral2 = await configContract.addCollateral(ContractAdds.Collateral_2)
    await addCollateral2.wait();

    
  //set validators
  const chain = await ethers.getContractAt("ChainContract", ContractAdds.ChainContract);
  const setValidators = await chain.setValidators(config.validators);
  await setValidators.wait();

  //set reward token
  const rewardToken = await ethers.getContractAt("Reward", ContractAdds.Reward);
 const setRewardToken = await rewardToken.addRewardToken(ContractAdds.Reward);
 await setRewardToken.wait();

  //pool set usd address
  const pool = await ethers.getContractAt("Pool", ContractAdds.Pool);
  const setUsdAddress = await pool.setUsdAddress(ContractAdds.USD);
  await setUsdAddress.wait();

  //usd set pool address
  const usd = await ethers.getContractAt("USD", ContractAdds.USD);
  const setPoolAddress = await usd.setPool(ContractAdds.Pool);
  await setPoolAddress.wait();

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
