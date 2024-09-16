// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title GnosisSafe Interface
 * @notice Interface for interacting with Gnosis Safe contracts
 */
interface GnosisSafe {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (bool success);
}

/**
 * @title MementoMori
 * @notice A contract for managing and executing digital wills on the blockchain
 * @dev This contract allows users to create, update, and execute wills that distribute various types of assets
 */
contract MementoMori is Ownable {
    // State variables
    uint256 public immutable fee;
    IRouterClient private immutable s_router;
    LinkTokenInterface private immutable s_linkToken;
    uint64 public immutable chainSelector;

    mapping(address => bytes32) public willHashes;

    // Events
    event WillExecuted(address indexed owner);
    event ExecutionRequested(address indexed owner);
    event WillCreated(address indexed owner);
    event WillUpdated(address indexed owner);
    event ExecutionCancelled(address indexed owner);
    event WillDeleted(address indexed owner);
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        Will will,
        address feeToken,
        uint256 fees
    );

    // Structs
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

    // Errors
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error NotExecutor();
    error ValueLessThanFee(uint256 fee, uint256 value);
    error HashesDontMatch();
    error ChainSelectorsDontMatch();
    error StillInCooldown(uint256 current, uint256 cooldown);
    error TransferFailed();

    /**
     * @notice Contract constructor
     * @param _fee Fee for creating or updating a will
     * @param _router Address of the CCIP router
     * @param _link Address of the LINK token
     * @param _chainSelector Identifier for the current blockchain
     */
    constructor(
        uint256 _fee,
        address _router,
        address _link,
        uint64 _chainSelector
    ) {
        fee = _fee;
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        chainSelector = _chainSelector;
    }

    /**
     * @notice Modifier to restrict access to will executors
     * @param will The will to check for executors
     */
    modifier onlyExecutors(Will calldata will) {
        if (!isExecutor(will)) {
            revert NotExecutor();
        }
        _;
    }

    /**
     * @notice Check if the caller is an executor of the will
     * @param will The will to check
     * @return bool True if the caller is an executor, false otherwise
     */
    function isExecutor(Will calldata will) internal view returns (bool) {
        for (uint256 i = 0; i < will.executors.length; i++) {
            if (msg.sender == will.executors[i]) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Save or update the hash of a will
     * @param wills Array of wills to hash
     * @param operationType Type of operation (0: create, 1: update, 2: cancel)
     */
    function saveWillHash(
        Will[] calldata wills,
        uint operationType
    ) external payable {
        if (msg.value < fee) {
            revert ValueLessThanFee(fee, msg.value);
        }
        bytes32 willHash = keccak256(abi.encode(wills));
        willHashes[msg.sender] = willHash;

        if (operationType == 0) {
            emit WillCreated(msg.sender);
        } else if (operationType == 1) {
            emit WillUpdated(msg.sender);
        } else if (operationType == 2) {
            emit ExecutionCancelled(msg.sender);
        }
    }

    /**
     * @notice Delete a will
     */
    function deleteWill() external {
        delete willHashes[msg.sender];
        emit WillDeleted(msg.sender);
    }

    /**
     * @notice Request execution of a will
     * @param wills Array of wills to execute
     */
    function requestExecution(
        Will[] calldata wills
    ) external payable onlyExecutors(wills[0]) {
        bytes32 willHash = keccak256(abi.encode(wills));
        willHashes[msg.sender] = willHash;
        emit ExecutionRequested(wills[0].baseAddress);
    }

    /**
     * @notice Execute a will, distributing assets to beneficiaries
     * @param wills Array of wills to execute
     */
    function execute(Will[] calldata wills) external onlyExecutors(wills[0]) {
        Will memory will = wills[0];
        if (keccak256(abi.encode(wills)) != willHashes[will.safe]) {
            revert HashesDontMatch();
        }
        if (will.chainSelector != chainSelector) {
            revert ChainSelectorsDontMatch();
        }
        if (block.timestamp < will.requestTime + will.cooldown) {
            revert StillInCooldown(
                block.timestamp,
                will.requestTime + will.cooldown
            );
        }

        executeTokenTransfers(will);
        executeNFTTransfers(will);
        executeERC1155Transfers(will);
        executeNativeTransfers(will);

        if (wills.length > 1) {
            for (uint i = 1; i < wills.length; i++) {
                sendMessage(
                    wills[i].chainSelector,
                    wills[i].xChainAddress,
                    wills[i]
                );
            }
        }
        emit WillExecuted(will.safe);
    }

    /**
     * @notice Execute token transfers for a will
     * @param will The will containing token transfer instructions
     */
    function executeTokenTransfers(Will memory will) internal {
        for (uint256 i = 0; i < will.tokens.length; i++) {
            uint256 balance = IERC20(will.tokens[i].contractAddress).balanceOf(
                will.safe
            );
            if (balance == 0) continue;

            for (uint256 j = 0; j < will.tokens[i].beneficiaries.length; j++) {
                uint256 amount = calculateAmount(
                    balance,
                    will.tokens[i].percentages[j]
                );
                if (amount == 0) continue;

                if (
                    !GnosisSafe(will.safe).execTransactionFromModule(
                        will.tokens[i].contractAddress,
                        0,
                        abi.encodeWithSignature(
                            "transfer(address,uint256)",
                            will.tokens[i].beneficiaries[j],
                            amount
                        ),
                        Enum.Operation.Call
                    )
                ) {
                    revert TransferFailed();
                }
            }
        }
    }

    /**
     * @notice Execute NFT transfers for a will
     * @param will The will containing NFT transfer instructions
     */
    function executeNFTTransfers(Will memory will) internal {
        for (uint256 i = 0; i < will.nfts.length; i++) {
            for (uint256 j = 0; j < will.nfts[i].tokenIds.length; j++) {
                if (
                    IERC721(will.nfts[i].contractAddress).ownerOf(
                        will.nfts[i].tokenIds[j]
                    ) != will.safe
                ) continue;

                if (
                    !GnosisSafe(will.safe).execTransactionFromModule(
                        will.nfts[i].contractAddress,
                        0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256)",
                            will.safe,
                            will.nfts[i].beneficiaries[j],
                            will.nfts[i].tokenIds[j]
                        ),
                        Enum.Operation.Call
                    )
                ) {
                    revert TransferFailed();
                }
            }
        }
    }

    /**
     * @notice Execute ERC1155 transfers for a will
     * @param will The will containing ERC1155 transfer instructions
     */
    function executeERC1155Transfers(Will memory will) internal {
        for (uint256 i = 0; i < will.erc1155s.length; i++) {
            uint balance = IERC1155(will.erc1155s[i].contractAddress).balanceOf(
                will.safe,
                will.erc1155s[i].tokenId
            );
            if (balance == 0) continue;

            for (
                uint256 j = 0;
                j < will.erc1155s[i].beneficiaries.length;
                j++
            ) {
                uint256 amount = balance > 1
                    ? calculateAmount(balance, will.erc1155s[i].percentages[j])
                    : 1;
                if (amount == 0) continue;

                if (
                    !GnosisSafe(will.safe).execTransactionFromModule(
                        will.erc1155s[i].contractAddress,
                        0,
                        abi.encodeWithSignature(
                            "safeTransferFrom(address,address,uint256,uint256,bytes)",
                            will.safe,
                            will.erc1155s[i].beneficiaries[j],
                            will.erc1155s[i].tokenId,
                            amount,
                            ""
                        ),
                        Enum.Operation.Call
                    )
                ) {
                    revert TransferFailed();
                }
            }
        }
    }

    /**
     * @notice Execute native token transfers for a will
     * @param will The will containing native token transfer instructions
     */
    function executeNativeTransfers(Will memory will) internal {
        uint nativBalance = will.safe.balance;
        for (uint256 i = 0; i < will.native[0].beneficiaries.length; i++) {
            uint256 nativeAmount = calculateAmount(
                nativBalance,
                will.native[0].percentages[i]
            );
            if (nativeAmount == 0) continue;

            if (
                !GnosisSafe(will.safe).execTransactionFromModule(
                    will.native[0].beneficiaries[i],
                    nativeAmount,
                    "",
                    Enum.Operation.Call
                )
            ) {
                revert TransferFailed();
            }
        }
    }

    /**
     * @notice Send a cross-chain message
     * @param destinationChainSelector The identifier for the destination blockchain
     * @param receiver The address of the receiver on the destination chain
     * @param will The will to be sent
     * @return messageId The ID of the sent message
     */
    function sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        Will calldata will
    ) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(will),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            feeToken: address(s_linkToken)
        });

        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        s_linkToken.approve(address(s_router), fees);

        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            will,
            address(s_linkToken),
            fees
        );

        return messageId;
    }

    /**
     * @notice Calculate the amount of tokens a beneficiary will receive
     * @param balance Total balance of tokens
     * @param percentage Percentage of tokens to be received (0-100)
     * @return uint256 Amount of tokens to be received
     */
    function calculateAmount(
        uint256 balance,
        uint256 percentage
    ) internal pure returns (uint256) {
        return (balance * percentage) / 100;
    }

    /**
     * @notice Withdraw contract balance
     * @param recipient Address to receive the withdrawn amount
     * @param amount Amount to withdraw
     */
    function withdraw(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Get the LINK token balance of the contract
     * @return uint256 LINK token balance
     */
    function getBalance() public view returns (uint) {
        return s_linkToken.balanceOf(address(this));
    }
}
