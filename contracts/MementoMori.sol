// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import{IERC20} from
    "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import{IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import{IERC1155} from
    "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import{Ownable} from
    "@openzeppelin/contracts/access/Ownable.sol";

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

interface GnosisSafe {
  /// @dev Allows a Module to execute a Safe transaction without any further
  /// confirmations.
  /// @param to Destination address of module transaction.
  /// @param value Ether value of module transaction.
  /// @param data Data payload of module transaction.
  /// @param operation Operation type of module transaction.

  function execTransactionFromModule(address to, uint256 value,
                                     bytes calldata data,
                                     Enum.Operation operation) external
      returns(bool success);

}

/**
 * @title The MementoMori contract
 * @notice A module that distributes the assets of a user's Gnosis Safe upon
 * their death
 */

contract MementoMori is
Ownable() {
  uint256 private constant TRANSFER_GAS = 21000;
  uint256 public fee;

  event WillExecuted(address indexed owner);
  event ExecutionRequested(address indexed owner);
  event WillCreated(address indexed owner);
  event ExecutionCancelled(address indexed owner);
  event WillDeleted(address indexed owner);

  struct Will {
    bool isActive;
    uint requestTime;
    uint cooldown;
    Native native;
    Token[] tokens;
    NFT[] nfts;
    ERC1155[] erc1155s;
    address[] executors;

  }

  struct Native {
    address[] beneficiaries;
    uint8[] percentages;
  } 
  struct Token {
    address contractAddress;
    address[] beneficiaries;
    uint8[] percentages;
  }
  struct NFT {
    address contractAddress;
    uint256[] tokenIds;
    address[] beneficiaries;
  }
  struct ERC1155 {
    address contractAddress;
    uint256 tokenId;
    address[] beneficiaries;
    uint8[] percentages;

  }

  mapping(address => Will) public willMap;
  mapping(address => bool) public exists;

  /**
   * @notice Executes once when a contract is created to initialize state
   * variables
   *
   * @param _fee Fee charged for will creation
   */

  constructor(uint256 _fee) { fee = _fee; }

  /**
 * @notice Creates a Will struct. If a will for the sender address exists it is
 updated

 * @param _tokens Array of token structs
   @param _nfts Array of NFT structs
   @param _1155s Array of ERC1155 structs
   @param _native Native struct
 */
  function createWill(uint _cooldown, Native calldata _native,
                      Token[] calldata _tokens, NFT[] calldata _nfts,
                      ERC1155[] calldata _1155s, address[] calldata _executors

                      ) external payable {
    require(msg.value >= fee, 'value must be greater than fee');
    require(_native.beneficiaries.length == _native.percentages.length, "Invalid native");
    uint8 totalNativeShares = 0;
    uint256 nativePercentagesLength = _native.percentages.length;
    for (uint256 i = 0; i < nativePercentagesLength; i++) {
      totalNativeShares += _native.percentages[i];
    }
    require(totalNativeShares == 100, "Invalid native");

    
    uint256 tokensLength = _tokens.length;
    if (tokensLength > 0) { 
      for (uint256 i = 0; i < tokensLength; i++) {
        require(
            _tokens[i].beneficiaries.length == _tokens[i].percentages.length,
            "Invalid tokens");
        uint8 totalShares = 0;
        for (uint256 j = 0; j < _tokens[i].percentages.length; j++) {
          totalShares += _tokens[i].percentages[j];
        }
        require(totalShares == 100, "Invalid tokens");
      }
      }

    
    uint256 erc1155sLength = _1155s.length;
    if (erc1155sLength > 0) {
      for (uint256 i = 0; i < erc1155sLength; i++) {
        require(_1155s[i].beneficiaries.length == _1155s[i].percentages.length,
                "Invalid erc1155s");
        uint8 totalShares = 0;
        for (uint256 j = 0; j < _1155s[i].percentages.length; j++) {
          totalShares += _1155s[i].percentages[j];
        }
        require(totalShares == 100, "Invalid er1155s");
      }
    }

    if (exists[msg.sender]) {
      delete willMap[msg.sender];
    }
    Will storage newWill = willMap[msg.sender];
    newWill.isActive = false;

    for (uint i = 0; i < tokensLength; i++) {
     if (_tokens[i].contractAddress != address(0)) {
      newWill.tokens.push(_tokens[i]);
    }
    }
    uint nftsLength = _nfts.length; 
    for (uint i = 0; i < nftsLength; i++) {
     if (_nfts[i].contractAddress != address(0)) {
      newWill.nfts.push(_nfts[i]);
    }
      }

    for (uint i = 0; i < erc1155sLength; i++) {
     if (_1155s[i].contractAddress != address(0)) {
      newWill.erc1155s.push(_1155s[i]);
    }
    }

    newWill.native = _native;
    newWill.cooldown = _cooldown;
    newWill.executors = _executors;

    exists[msg.sender] = true;

    emit WillCreated(msg.sender);
  }

  /**
 * @notice Calculates the amount of tokens a beneficiary will receive

 * @param balance owner token balance
 * @param percentage percentage of total tokens beneficiary will recieve
 */
  function calculateAmount(uint256 balance, uint256 percentage) public pure
  returns(uint) {
    uint bp = percentage * 100;
    return balance * bp / 10000;
  }
  /**
 * @notice Calculates the amount of native tokens a beneficiary will receive
 taking into account gas needed to complete transfers

 * @param balance owner token balance
 * @param percentage percentage of total tokens beneficiary will recieve
 * @param numBeneficiaries number of beneficiaries splitting the balance
 */
  function calculateNativeAmount(uint256 balance, uint256 percentage,
                                 uint256 numBeneficiaries,
                                 uint256 gasPrice) public pure
  returns(uint) {
    uint gasNeeded = (gasPrice * TRANSFER_GAS) * numBeneficiaries;
    require(balance > gasNeeded, "05");
    uint balanceMinusGas = balance - gasNeeded;
    uint bp = percentage * 100;
    return (balanceMinusGas * bp) / 10000;
  }

  /**
 * @notice Executes the will, distributing assets among beneficiaries

 * @param owner address of will owner
   @param gasPrice current network gas price

 */

  function execute(address owner, uint256 gasPrice) external onlyExecutors(
      owner) {
    Will storage will = willMap[owner];
    require(will.isActive == true);
    require(block.timestamp - will.requestTime >= will.cooldown,
            "Execution still in cooldown");
    if (will.tokens.length > 0) {
      uint256 tokensLength = will.tokens.length;
      for (uint256 i = 0; i < tokensLength; i++) {
        IERC20 token = IERC20(will.tokens[i].contractAddress);
        uint256 balance = token.balanceOf(owner);
        if (balance / will.tokens[i].beneficiaries.length > 0) {
          for (uint256 j = 0; j < will.tokens[i].beneficiaries.length; j++) {
            uint256 amount =
                calculateAmount(balance, will.tokens[i].percentages[j]);

            require(GnosisSafe(owner).execTransactionFromModule(
                        will.tokens[i].contractAddress, 0,
                        abi.encodeWithSignature("transfer(address,uint256)",
                                                will.tokens[i].beneficiaries[j],
                                                amount),
                        Enum.Operation.Call),
                    "Token transfer failed");
          }
        }
      }
    }
    if (will.nfts.length > 0) {
      uint256 nftsLength = will.nfts.length;
      for (uint256 i = 0; i < nftsLength; i++) {
        IERC721 nft = IERC721(will.nfts[i].contractAddress);
        for (uint256 j = 0; j < will.nfts[i].tokenIds.length; j++) {
          if (nft.ownerOf(will.nfts[i].tokenIds[j]) == owner) {
            require(GnosisSafe(owner).execTransactionFromModule(
                        will.nfts[i].contractAddress, 0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256)", owner,
                            will.nfts[i].beneficiaries[j],
                            will.nfts[j].tokenIds[j]),
                        Enum.Operation.Call),
                    "NFT transfer failed");
          }
        }
      }
    }
    if (will.erc1155s.length > 0) {
      uint256 erc1155sLength = will.erc1155s.length;
      for (uint256 i = 0; i < erc1155sLength; i++) {
        IERC1155 token = IERC1155(will.erc1155s[i].contractAddress);
        uint256 balance = token.balanceOf(owner, will.erc1155s[i].tokenId);
        if (balance / will.erc1155s[i].beneficiaries.length > 0) {
          for (uint256 j = 0; j < will.erc1155s[i].beneficiaries.length; j++) {
            uint256 amount;
            if (balance > 1) {
              amount =
                  calculateAmount(balance, will.erc1155s[i].percentages[j]);
            } else if (balance == 1) {
              amount = 1;
            }

            require(GnosisSafe(owner).execTransactionFromModule(
                        will.erc1155s[i].contractAddress, 0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256,uint256,"
                            "bytes)",
                            owner, will.erc1155s[i].beneficiaries[j],
                            will.erc1155s[i].tokenId, amount, "0x"),
                        Enum.Operation.Call),
                    "erc1155 transfer failed");
          }
        }
      }
    }
    uint256 nativeBalance = owner.balance;
    for (uint256 i = 0; i < will.native.beneficiaries.length; i++) {
      uint256 nativeAmount =
          calculateNativeAmount(nativeBalance, will.native.percentages[i],
                                will.native.beneficiaries.length, gasPrice);
      require(GnosisSafe(owner).execTransactionFromModule(
                  will.native.beneficiaries[i], nativeAmount, '',
                  Enum.Operation.Call),
              "Native transfer failed");
    }
    will.isActive = false;

    emit WillExecuted(owner);
  }

  modifier onlyExecutors(address owner) {
    Will memory will = getWill(owner);
    bool isExecutor = false;
    for (uint256 i = 0; i < will.executors.length; i++) {
      if (msg.sender == will.executors[i]) {
        isExecutor = true;
        break;
      }
    }

    require(isExecutor == true, 'You are not a will beneficiary');
    _;
  }

  function requestExecution(address owner) external onlyExecutors(owner) {
    Will storage will = willMap[owner];
    will.isActive = true;
    will.requestTime = block.timestamp;
    emit ExecutionRequested(owner);
  }
  function cancelExecution() external {
    Will storage will = willMap[msg.sender];
    will.isActive = false;
    will.requestTime = 0;
    emit ExecutionCancelled(msg.sender);
  }

  function setFee(uint256 _fee) external onlyOwner { fee = _fee; }
  function deleteWill() external {
    delete willMap[msg.sender];
    emit WillDeleted(msg.sender);
  }

  function getWill(address _address) public view returns(Will memory) {
    return willMap[_address];
  }

  function withdraw(address payable recipient, uint256 amount)
      external payable onlyOwner {
    recipient.transfer(amount);
  }
}