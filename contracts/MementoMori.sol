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
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

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
    uint256 public fee;
  IRouterClient  s_router;
  LinkTokenInterface private s_linkToken;
  uint64 chainSelector;
  mapping(address => bytes32) public willHashes;
  
  

  event WillExecuted(address indexed owner);
  event ExecutionRequested(address indexed owner);
  event WillCreated(address indexed owner);
  event ExecutionCancelled(address indexed owner);
  event WillDeleted(address indexed owner);
      // Event emitted when a message is sent to another chain.
      // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        Will will, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

  error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
  

  struct Will {
    bool isActive;
    uint requestTime;
    uint cooldown;
    Native[] native;
    Token[] tokens;
    NFT[] nfts;
    ERC1155[] erc1155s;
    address[] executors;
    uint64 chainSelector;
    address safe;
    address xChainAddress;
    address baseAddress;

   

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



  /**
   * @notice Executes once when a contract is created to initialize state
   * variables
   *
   * @param _fee Fee charged for will creation
   */

  constructor(uint256 _fee, address _router, address _link, uint64 _chainSelector) { 
    fee = _fee;
    s_router = IRouterClient(_router);
    s_linkToken = LinkTokenInterface(_link);
    chainSelector = _chainSelector;
    
    
  
    }

  /**
 * @notice Saves a hash of the user's will struct used to verify validity of input for execute function

 * @param  wills Hash of user's will struct 

 */
  function saveWillHash(Will[] calldata wills) external payable {
    require(msg.value >= fee, 'value must be greater than fee');
    bytes32 willHash = keccak256(abi.encode(wills));
    willHashes[msg.sender] = willHash;
  

    

    emit WillCreated(msg.sender);
                      
  }

  /**
 * @notice Calculates the amount of tokens a beneficiary will receive given a percentage

 * @param balance owner token balance
 * @param percentage percentage of total tokens beneficiary will recieve
 */
  function calculateAmount(uint256 balance, uint256 percentage) public pure
  returns(uint) {
    uint bp = percentage * 100;
    return balance * bp / 10000;
  }

       /// @notice Sends data to receiver on the destination chain.
    /// @dev Assumes your contract has sufficient LINK.
    /// @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param will The string text to be sent.
    /// @return messageId The ID of the message that was sent.
      function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        Will calldata will
    ) internal  returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: abi.encode(will), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(s_linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            will,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function getBalance() public view returns (uint) {
        return s_linkToken.balanceOf(address(this));
    }

  /**
 * @notice Executes the will, distributing assets among beneficiaries

 * @param wills array of will structs

 */

  function execute(Will[] calldata wills) external onlyExecutors(
      wills[0]) {
    Will memory will = wills[0];
    require(keccak256(abi.encode(wills)) == willHashes[will.safe], "hashes don't match");
    require(will.chainSelector == chainSelector, "chain selectors don't match");
    
    require(block.timestamp - will.requestTime >= will.cooldown,
            "Execution still in cooldown");
    if (will.tokens.length > 0) {
    
  
      for (uint256 i = 0; i < will.tokens.length; i++) {
      
      
        uint256 balance = IERC20(will.tokens[i].contractAddress).balanceOf(will.safe);
        if (balance / will.tokens[i].beneficiaries.length > 0) {
          for (uint256 j = 0; j < will.tokens[i].beneficiaries.length; j++) {
            uint256 amount =
                calculateAmount(balance, will.tokens[i].percentages[j]);

            require(GnosisSafe(will.safe).execTransactionFromModule(
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
  
      for (uint256 i = 0; i < will.nfts.length; i++) {
  
        for (uint256 j = 0; j < will.nfts[i].tokenIds.length; j++) {
          if (IERC721(will.nfts[i].contractAddress).ownerOf(will.nfts[i].tokenIds[j]) == will.safe) {
            require(GnosisSafe(will.safe).execTransactionFromModule(
                        will.nfts[i].contractAddress, 0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256)", will.safe,
                            will.nfts[i].beneficiaries[j],
                            will.nfts[j].tokenIds[j]),
                        Enum.Operation.Call),
                    "NFT transfer failed");
          }
        }
      }
    }
    if (will.erc1155s.length > 0) {
    
      for (uint256 i = 0; i < will.erc1155s.length; i++) {
      
        uint balance = IERC1155(will.erc1155s[i].contractAddress).balanceOf(will.safe, will.erc1155s[i].tokenId);
        if (balance / will.erc1155s[i].beneficiaries.length > 0) {
          for (uint256 j = 0; j < will.erc1155s[i].beneficiaries.length; j++) {
            uint256 amount;
            if (balance > 1) {
              amount =
                  calculateAmount(balance, will.erc1155s[i].percentages[j]);
            } else if (balance == 1) {
              amount = 1;
            }

            require(GnosisSafe(will.safe).execTransactionFromModule(
                        will.erc1155s[i].contractAddress, 0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256,uint256,"
                            "bytes)",
                            will.safe, will.erc1155s[i].beneficiaries[j],
                            will.erc1155s[i].tokenId, amount, "0x"),
                        Enum.Operation.Call),
                    "erc1155 transfer failed");
          }
        }
      }
    }
       uint nativBalance = will.safe.balance;
       for (uint256 i = 0; i < will.native[0].beneficiaries.length; i++) {
         uint256 nativeAmount =
          calculateAmount(nativBalance, will.native[0].percentages[i]);
           require(GnosisSafe(will.safe).execTransactionFromModule(
                  will.native[0].beneficiaries[i], nativeAmount, '',
                  Enum.Operation.Call),
              "Native transfer failed");
    }
    if (wills.length > 1) {
     for (uint i = 1; i < wills.length; i++) {

         sendMessage(wills[i].chainSelector, wills[i].xChainAddress, wills[i]);
             }
    }
    emit WillExecuted(will.safe);
  }

 

    /**
 * @notice restricts functions to will executors, tipically will beneficiaries and owner

 * @param will Will struct to check for executors


 */
 modifier onlyExecutors(Will calldata will) {

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




  function withdraw(address payable recipient, uint256 amount)
      external payable onlyOwner {
    recipient.transfer(amount);
  }

}