// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MementoMori.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

/**
 * @title The MementoMori contract
 * @notice A module that distributes the assets of a user's Gnosis Safe upon
 * their death
 */

contract MementoMoriXChain is MementoMori, CCIPReceiver {
    /**
     * @notice Contract constructor
     * @param _fee Fee for creating or updating a will
     * @param _router Address of the CCIP router
     * @param _link Address of the LINK token
     * @param _chainSelector Identifier for the current blockchain
     */
    constructor(
        uint _fee,
        address _router,
        address _link,
        uint64 _chainSelector
    ) MementoMori(_fee, _router, _link, _chainSelector) CCIPReceiver(_router) {}

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        Will message // The message that was received.
    );

    function execute(Will memory will) internal {
        executeTokenTransfers(will);
        executeNFTTransfers(will);
        executeERC1155Transfers(will);
        executeNativeTransfers(will);

        emit WillExecuted(will.safe);
    }

    /**
     * @notice Called on reception of a cross-chain message
     * @param any2EvmMessage The message received
    
     */
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
