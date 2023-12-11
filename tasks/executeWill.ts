import { task } from 'hardhat/config'

import { ethers } from 'ethers'
import Safe, { SafeFactory, SafeAccountConfig, EthersAdapter } from '@safe-global/protocol-kit'
import { ContractNetworksConfig } from '@safe-global/safe-core-sdk'
import { Signer } from '@ethersproject/abstract-signer'
import { JsonRpcSigner, Provider } from '@ethersproject/providers'
import { type SafeTransactionDataPartial } from '@safe-global/safe-core-sdk-types'
import mementoMoriAbi from '../artifacts/contracts/MementoMori.sol/MementoMori.json'
import { type NativeToken, type Token, type Will } from '../test/types'

task('executeWill', async () => {
  const PK = process.env.PK
  const RPC_URL = process.env.RPC_URL

  console.log(RPC_URL)
  if (PK != null) {
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL)
    const wallet = new ethers.Wallet(PK).connect(provider)

    const ethAdapter = new EthersAdapter({
      ethers,
      signerOrProvider: wallet
    })

    const chainId = await ethAdapter.getChainId()
    console.log(chainId)
    const sepoliaLink: Token = {
      contractAddress: '0x779877A7B0D9E8603169DdbD7836e478b4624789',
      beneficiaries: ['0x43Fd37b3587fB30E319De4A276AD49E7969E23DD'],
      percentages: [100]
    }
    const baseGLink: Token = {
      contractAddress: '0xd886e2286fd1073df82462ea1822119600af80b6',
      beneficiaries: ['0x43Fd37b3587fB30E319De4A276AD49E7969E23DD'],
      percentages: [100]
    }
    const native: NativeToken = {
      beneficiaries: ['0x43Fd37b3587fB30E319De4A276AD49E7969E23DD'],
      percentages: [100]
    }
    const sepoliaSelector = '16015286601757825753'
    const baseGSelector = '5790810961207155433'
    const baseGSafe = '0xF3b1E12464A9fc7dD3b920Bc45c77A1923dF47Ea'
    const sepoliaMmAddress = '0xBFBb7B3eb4f0269B07934E7B7AD65cF9A124fDdC'
    const baseGMmAddress = '0xfC880a14F8Bc0D3DfFDab6E8F1D0b7bF189486E5'
    const sepoliaSafe = '0x3FfF5f04A2efE648835293ad17162d497c0dD96C'
    const will: Will = {
      isActive: true,
      requestTime: Date.now(),
      cooldown: 0,
      native,
      tokens: [sepoliaLink],
      nfts: [],
      erc1155s: [],
      executors: [sepoliaSafe, '0x43Fd37b3587fB30E319De4A276AD49E7969E23DD'],
      chainSelector: sepoliaSelector,
      safe: sepoliaSafe,
      xChainAddress: sepoliaMmAddress

    }

    const xChainWill: Will = {
      isActive: false,
      requestTime: 0,
      cooldown: 0,
      native,
      tokens: [baseGLink],
      nfts: [],
      erc1155s: [],
      executors: [],
      chainSelector: baseGSelector,
      safe: baseGSafe,
      xChainAddress: baseGMmAddress

    }

    const safeSdk: Safe = await Safe.create({ ethAdapter, safeAddress: sepoliaSafe })

    const iface = new ethers.utils.Interface(mementoMoriAbi.abi)
    const data = iface.encodeFunctionData('execute', [[will, xChainWill]])
    const safeTransactionData: SafeTransactionDataPartial = {
      to: sepoliaMmAddress,
      value: '0',
      data

    }
    const safeTransaction = await safeSdk.createTransaction({ safeTransactionData })
    console.log('sending tx')
    const executeTxResponse = await safeSdk.executeTransaction(safeTransaction, { gasLimit: 1000000 })
    console.log(executeTxResponse.hash)
    await executeTxResponse.transactionResponse?.wait()
  }
})
