// import config before anything else
import { type HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-deploy'
// eslint-disable-next-line @typescript-eslint/no-var-requires, n/no-path-concat
require('dotenv').config({ path: __dirname + '/.env' })

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      { version: '0.8.19' },
      { version: '0.8.0' },
      { version: '0.8.9' },
      { version: '0.8.20' },
      { version: '0.7.0' },
      { version: '0.8.1', settings: {} }
    ]
  },
  networks: {
    localhost: {
      url: 'http://localhost:8545/'
    },
    hardhat: {
      forking: {
        url: process.env.RPC_URL != null ? process.env.RPC_URL : ''
      }
    }
  },
  mocha: {
    timeout: 120000
  }
}

export default config
