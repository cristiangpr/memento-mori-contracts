// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.20;

import  "./MementoMori.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";



/**
 * @title The MementoMori contract
 * @notice A module that distributes the assets of a user's Gnosis Safe upon
 * their death
 */

 contract MementoMoriXChain is
     MementoMori, CCIPReceiver  {
    
    
 constructor(uint _fee, address _router, address _link, uint64 _chainSelector ) MementoMori(_fee, _router, _link, _chainSelector) CCIPReceiver(_router) {
  
 }

     // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        Will message // The message that was received.
    );

  function execute(Will memory will) internal  {
  
 
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
        IERC721 nft = IERC721(will.nfts[i].contractAddress);
        for (uint256 j = 0; j < will.nfts[i].tokenIds.length; j++) {
          if (nft.ownerOf(will.nfts[i].tokenIds[j]) == will.safe) {
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
  
    

    emit WillExecuted(will.safe);
  }
  
    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
     Will memory will = abi.decode(any2EvmMessage.data, (Will)); // abi-decoding of the sent string message
        bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
        address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address
  
        
       execute(will);
       emit MessageReceived(messageId, sourceChainSelector, sender, will);
    }

}