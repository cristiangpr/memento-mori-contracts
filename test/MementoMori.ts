import { expect } from 'chai'
import { ethers, deployments } from 'hardhat'
import type Safe from '@safe-global/protocol-kit'
import {
  type ContractNetworksConfig,
  EthersAdapter,
  SafeFactory
} from '@safe-global/protocol-kit'
import {
  type SafeTransaction,
  type SafeTransactionDataPartial
} from '@safe-global/safe-core-sdk-types'
import { type SafeAccountConfig } from '@safe-global/safe-core-sdk'
import mementoMoriAbi from '../artifacts/contracts/MementoMori.sol/MementoMori.json'
import {
  type Will,
  type Erc1155,
  type NativeToken,
  type NFT,
  type Token
} from './types'
import { time } from '@nomicfoundation/hardhat-network-helpers'
// eslint-disable-next-line @typescript-eslint/no-var-requires
require('dotenv').config()

const token1: Token = {
  contractAddress: '0xb5B640E6414b6DeF4FC9B3C1EeF373925effeCcF',
  beneficiaries: [
    '0x6De9840D3f72e1F0bDeA686b6A06284595C61614',
    '0x82dEa1ca00b61BF2fcA626f8ba66d479aE55C923'
  ],
  percentages: [50, 50]
}
const token2: Token = {
  contractAddress: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
  beneficiaries: [
    '0x6De9840D3f72e1F0bDeA686b6A06284595C61614',
    '0x82dEa1ca00b61BF2fcA626f8ba66d479aE55C923'
  ],
  percentages: [50, 50]
}

const NFT1: NFT = {
  contractAddress: '0x432C789F56B6BCaBCdc4b542b610a27A01Df9E88',
  tokenIds: [0],
  beneficiaries: ['0x6De9840D3f72e1F0bDeA686b6A06284595C61614']
}

const NFT2: NFT = {
  contractAddress: '0xd392BE1391c88C9329B2f8f08050205482E9Ab9D',
  tokenIds: [0],
  beneficiaries: ['0x82dEa1ca00b61BF2fcA626f8ba66d479aE55C923']
}

const erc1155NFT: Erc1155 = {
  contractAddress: '0xbeB9A26c85cd1A253940F1BB6Ab8fd7796720C11',
  tokenId: 0,
  beneficiaries: ['0x6De9840D3f72e1F0bDeA686b6A06284595C61614'],
  percentages: [100]
}
const erc1155Token: Erc1155 = {
  contractAddress: '0xbeB9A26c85cd1A253940F1BB6Ab8fd7796720C11',
  tokenId: 1,
  beneficiaries: [
    '0x6De9840D3f72e1F0bDeA686b6A06284595C61614',
    '0x82dEa1ca00b61BF2fcA626f8ba66d479aE55C923'
  ],
  percentages: [50, 50]
}

const native: NativeToken = {
  beneficiaries: [
    '0x6De9840D3f72e1F0bDeA686b6A06284595C61614',
    '0x82dEa1ca00b61BF2fcA626f8ba66d479aE55C923'
  ],
  percentages: [50, 50]
}

const router = '0xa8c0c11bf64af62cdca6f93d3769b88bdd7cb93d'
const link = '0xd886e2286fd1073df82462ea1822119600af80b6'
// eslint-disable-next-line @typescript-eslint/no-loss-of-precision
const chainSelector = '5790810961207155433'

describe('MementoMori', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  // eslint-disable-next-line @typescript-eslint/explicit-function-return-type
  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }, options) => {
      await deployments.fixture() // ensure you start from a fresh deployments
      const fee = 1000000
      const [owner, beneficiary1, beneficiary2] = await ethers.getSigners()
      const ownerAddress: string = await owner.getAddress()
      console.log(ownerAddress)
      const benef1Address: string = await beneficiary1.getAddress()
      const benef2Address: string = await beneficiary2.getAddress()
      const MementoMori = await ethers.getContractFactory('MementoMori')
      const mementoMori = await MementoMori.deploy(
        fee,
        router,
        link,
        chainSelector
      )
      const will: Will = {
        isActive: false,
        requestTime: 0,
        cooldown: 0,
        native: [native],
        tokens: [token1, token2],
        nfts: [NFT1, NFT2],
        erc1155s: [erc1155NFT, erc1155Token],
        executors: [benef1Address, owner.address],
        chainSelector,
        safe: owner.address,
        xChainAddress: mementoMori.address,
        baseAddress: owner.address
      }

      return {
        mementoMori,
        fee,
        ownerAddress,
        owner,
        beneficiary1,
        beneficiary2,
        benef1Address,
        benef2Address,
        will
      }
    }
  )

  describe('Deployment', function () {
    it('Should set the right constructor variables', async function () {
      const { mementoMori, fee, ownerAddress } = await setupTest()

      expect(await mementoMori.fee()).to.equal(fee)
      expect(await mementoMori.owner()).to.equal(ownerAddress)
    })
  })

  describe('saveWillHash', function () {
    describe('Validations', function () {
      it('Should revert if the value is less than the fee', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.saveWillHash([will], 0, { value: 0 })
        ).to.be.revertedWithCustomError(mementoMori, 'ValueLessThanFee')
      })
    })
    describe('Operations', function () {
      it('Should save the correct hash and emit WillCreated event upon success', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.saveWillHash([will], 0, { value: 1000000 })
        ).to.emit(mementoMori, 'WillCreated')
      })
      it('Should save the correct hash and emit WillUpdated event upon success', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.saveWillHash([will], 1, { value: 1000000 })
        ).to.emit(mementoMori, 'WillUpdated')
      })
      it('Should save the correct hash and emit executionCancelled event upon success', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.saveWillHash([will], 2, { value: 1000000 })
        ).to.emit(mementoMori, 'ExecutionCancelled')
      })
    })
  })
  describe('requestExecution', function () {
    /* describe('Validations', function () {
      it('Should revert if the value is less than the fee', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.requestExecution([will], { value: 0 })
        ).to.be.revertedWith('value must be greater than fee')
      })
    }) */
    describe('Operations', function () {
      it('Should save the correct hash and emit executionRequested event upon success', async function () {
        const { mementoMori, will } = await setupTest()

        await expect(
          mementoMori.requestExecution([will], { value: 1000000 })
        ).to.emit(mementoMori, 'ExecutionRequested')
      })
    })
  })

  describe('getAmount', function () {
    it('Should set the right feee and owner', async function () {
      const { mementoMori, fee, ownerAddress } = await setupTest()

      expect(await mementoMori.fee()).to.equal(fee)
      expect(await mementoMori.owner()).to.equal(ownerAddress)
    })
  })

  describe('execute', function () {
    describe('transfers', function () {
      it('should disgtribute tokens in correct percentages', async function () {
        const {
          mementoMori,
          ownerAddress,
          benef1Address,
          owner,
          benef2Address,
          beneficiary1,
          beneficiary2
        } = await setupTest()
        const MyToken = await ethers.getContractFactory('MyToken')
        const myToken = await MyToken.deploy()
        const MyNFT = await ethers.getContractFactory('MyNFT')
        const myNFT = await MyNFT.deploy()
        const My1155 = await ethers.getContractFactory('My1155')
        const my1155 = await My1155.deploy()
        // Set up Gnosis Safe
        const ethAdapter = new EthersAdapter({
          ethers,
          signerOrProvider: owner
        })
        const chainId = await ethAdapter.getChainId()

        const contractNetworks: ContractNetworksConfig = {
          [chainId]: {
            safeMasterCopyAddress: '0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552',
            safeProxyFactoryAddress:
              '0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2',
            multiSendAddress: '0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761',
            multiSendCallOnlyAddress:
              '0x40A2aCCbd92BCA938b02010E17A5b8929b49130D',
            fallbackHandlerAddress:
              '0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4',
            signMessageLibAddress: '0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2',
            createCallAddress: '0x7cbB62EaA69F79e6873cD1ecB2392971036cFAa4',
            simulateTxAccessorAddress:
              '0x3d4BA2E0884aa488718476ca2FB8Efc291A46199'
          }
        }
        const safeVersion = '1.3.0'
        const safeFactory = await SafeFactory.create({
          ethAdapter,
          safeVersion,
          contractNetworks
        })
        console.log(safeFactory.getAddress())

        const owners = [ownerAddress]
        const threshold = 1
        const safeAccountConfig: SafeAccountConfig = {
          owners,
          threshold

          // ...
        }

        const safe: Safe = await safeFactory.deploySafe({ safeAccountConfig })
        const amount = ethers.BigNumber.from(ethers.utils.parseEther('1.0'))
        const safeAddress: string = await safe.getAddress()
        // Transfer assets to Safe
        const receipt = await owner.sendTransaction({
          to: safeAddress,
          value: amount,
          data: '0x'
        })
        await receipt.wait()
        console.log('safe balance', await safe.getBalance())

        const tokenReceipt = await myToken.mint(safeAddress, amount.toString())
        await tokenReceipt.wait()
        console.log('token balance', await myToken.balanceOf(safeAddress))

        const nftReceipt = await myNFT.safeMint(safeAddress)
        await nftReceipt.wait()
        console.log('nft balance', await myNFT.balanceOf(safeAddress))

        const erc1155NFTReceipt = await my1155.mint(safeAddress, 0, 1, '0x')
        await erc1155NFTReceipt.wait()
        console.log('1155 nft balance', await my1155.balanceOf(safeAddress, 0))

        const erc1155TokenReceipt = await my1155.mint(
          safeAddress,
          1,
          amount,
          '0x'
        )
        await erc1155TokenReceipt.wait()
        console.log(
          '1155 token balance',
          await my1155.balanceOf(safeAddress, 1)
        )

        const nativeToken: NativeToken = {
          beneficiaries: [benef1Address, benef2Address],
          percentages: [50, 50]
        }
        const token: Token = {
          contractAddress: myToken.address,
          beneficiaries: [benef1Address, benef2Address],
          percentages: [50, 50]
        }

        const NFT: NFT = {
          contractAddress: myNFT.address,
          tokenIds: [0],
          beneficiaries: [benef1Address]
        }

        const erc1155Nft: Erc1155 = {
          contractAddress: my1155.address,
          tokenId: 0,
          beneficiaries: [benef2Address],
          percentages: [100]
        }

        const erc1155Ft: Erc1155 = {
          contractAddress: my1155.address,
          tokenId: 1,
          beneficiaries: [benef1Address, benef2Address],
          percentages: [50, 50]
        }
        // Create a will for Safe
        const will: Will = {
          isActive: true,
          requestTime: await time.latest(),
          cooldown: 1,
          native: [nativeToken],
          tokens: [token],
          nfts: [NFT],
          erc1155s: [erc1155Nft, erc1155Ft],
          executors: [benef1Address, benef2Address, safeAddress],
          chainSelector,
          safe: safeAddress,
          xChainAddress: mementoMori.address,
          baseAddress: safeAddress
        }
        const IMementoMori = new ethers.utils.Interface(mementoMoriAbi.abi)
        const createWillData: string = IMementoMori.encodeFunctionData(
          'saveWillHash',
          [[will], 0]
        )
        const createWillTransaction: SafeTransactionDataPartial = {
          to: mementoMori.address,
          value: '10000000',
          data: createWillData,
          gasPrice: '500000000'
        }
        const safeCreateWillTransaction: SafeTransaction =
          await safe.createTransaction({
            safeTransactionData: createWillTransaction
          })
        console.log('1')
        await safe.signTransaction(safeCreateWillTransaction)
        console.log('saveHash')
        const executeCreateWillTxResponse = await safe.executeTransaction(
          safeCreateWillTransaction
        )

        await executeCreateWillTxResponse.transactionResponse?.wait()
        console.log(await mementoMori.willHashes(safeAddress))
        // Enable Memento Mori module
        const IenableModule = new ethers.utils.Interface([
          'function enableModule(address module)'
        ])

        const enableModuleData: string = IenableModule.encodeFunctionData(
          'enableModule',
          [mementoMori.address]
        )

        const safeEnableModuleTransactionData: SafeTransactionDataPartial = {
          to: ethers.utils.getAddress(safeAddress),
          value: '0',
          data: enableModuleData
        }

        const safeTransaction: SafeTransaction = await safe.createTransaction({
          safeTransactionData: safeEnableModuleTransactionData
        })

        const executeTxResponse = await safe.executeTransaction(safeTransaction)
        console.log('enable')
        await executeTxResponse.transactionResponse?.wait()
        await time.increase(100)

        // Execute the will

        const executeData: string = IMementoMori.encodeFunctionData('execute', [
          [will]
        ])
        const safeExecuteTransactionData: SafeTransactionDataPartial = {
          to: ethers.utils.getAddress(mementoMori.address),
          value: '0',
          data: executeData
        }

        const safeExecTransaction: SafeTransaction =
          await safe.createTransaction({
            safeTransactionData: safeExecuteTransactionData
          })
        console.log('execute')
        const safeExecuteTxResponse =
          await safe.executeTransaction(safeExecTransaction)

        await safeExecuteTxResponse.transactionResponse?.wait()

        // Check expected balances
        expect(await safe.isModuleEnabled(mementoMori.address)).to.equal(true)
        expect(await beneficiary1.getBalance()).to.equal(
          await beneficiary2.getBalance()
        )
        expect(await myToken.balanceOf(benef1Address)).to.equal(
          await myToken.balanceOf(benef2Address)
        )
        expect(await myToken.balanceOf(benef1Address)).to.equal(amount.div(2))
        expect(await myToken.balanceOf(benef2Address)).to.equal(amount.div(2))
        expect(await myNFT.balanceOf(benef1Address)).to.equal(1)
        expect(await my1155.balanceOf(benef2Address, 0)).to.equal(1)
        expect(await my1155.balanceOf(benef1Address, 1)).to.equal(
          await my1155.balanceOf(benef2Address, 1)
        )
        expect(await my1155.balanceOf(benef1Address, 1)).to.equal(amount.div(2))
        expect(await my1155.balanceOf(benef2Address, 1)).to.equal(amount.div(2))
      })
    })
  })
})
