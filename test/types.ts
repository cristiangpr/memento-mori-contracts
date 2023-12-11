export enum CooldownPeriod {
  OneWeek = 10080000,
  TwoWeeks = 20160000,
  OneMonth = 43200000,
}

export interface Beneficiary {
  address: string
  percentage: number
}

export interface NFTBeneficiary {
  tokenId: number
  beneficiary: string
}

export interface NFT {
  contractAddress: string
  beneficiaries: string[]
  tokenIds: number[]
}

export interface Token {
  contractAddress: string
  beneficiaries: string[]
  percentages: number[]
}

export interface Erc1155 {
  contractAddress: string
  tokenId: number
  beneficiaries: string[]
  percentages: number[]
}

export interface NativeToken {
  beneficiaries: string[]
  percentages: number[]
}

export interface UserInfo {
  firstName: string
  initial: string
  lastName: string
  birthDate?: string
  address?: string
}
export interface Will {
  isActive: boolean
  requestTime: number
  cooldown: number
  native: NativeToken
  tokens: Token[]
  nfts: NFT[]
  erc1155s: Erc1155[]
  executors: string[]
  chainSelector: any
  safe: string
  xChainAddress: string

}

export enum Form {
  Cooldown = 'cooldown',
  NativeToken = 'nativeToken',
  Tokens = 'tokens',
  NFTS = 'nfts',
  Erc1155s = 'erc1155s',
  Executors = 'executors',
}

export interface FormTypes {
  [Form.Cooldown]: number
  [Form.NativeToken]: NativeToken[]
  [Form.Erc1155s]: Erc1155[]
  [Form.Tokens]: Token[]
  [Form.NFTS]: NFT[]
  [Form.Executors]: string[]
}

export interface DisplayData {
  isActive: boolean
  requestTime: number
  cooldown: number
  nativeToken: NativeToken
  tokens?: Token[]
  nfts?: NFT[]
  erc1155s?: Erc1155[]
  executors: string[]
}
