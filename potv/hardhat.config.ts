import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import * as dotenv from "dotenv";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';
const config: HardhatUserConfig = {
  solidity: "0.8.19",
  networks: {
    "canto-testnet": {
      url: "https://canto-testnet.plexnode.wtf",
      accounts: [PRIVATE_KEY]
    },
    "arbitrum-sepolia": {
      url: "https://arb-sepolia.g.alchemy.com/v2/I-ZVEdUQy4Mk3rwbsNAIp_MVql6coseO",
      accounts: [PRIVATE_KEY]
    },
    tucana:{
      url: "https://evm-rpc.birdee-2.tucana.zone",
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan:{
    apiKey: {
      'tucana': 'empty'
    },
    customChains: [
      {
        network: "tucana",
        chainId: 712,
        urls: {
          apiURL: "https://explorer.birdee-2.tucana.zone/api",
          browserURL: "https://explorer.birdee-2.tucana.zone"
        }
      }
    ]
  }
};



export default config;
