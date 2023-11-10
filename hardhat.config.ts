import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-deploy';

const config: HardhatUserConfig = {
  
    solidity: { compilers: [{ version: '0.8.19' }, { version: '0.8.0' }, { version: '0.8.9' }, {version: '0.8.20'}, { version: '0.7.0' }, { version: '0.8.1', settings: {} }] },
  networks: {

 
    localhost: {
      url: 'http://localhost:8545/'
    },
  hardhat: {
    forking: {
      url: "https://eth-goerli.g.alchemy.com/v2/gyDS4bQd9EJYYf80T2JukPhszaT6rhgT",
    }
  }

  },
  mocha: {
    timeout: 120000
  }
}


export default config;
