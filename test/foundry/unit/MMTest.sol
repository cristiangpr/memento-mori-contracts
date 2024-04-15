// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../../../lib/forge-std/src/Script.sol";
import {MementoMori} from "../../../contracts/MementoMori.sol";
import {DeployMementoMori} from "../../../scripts/DeployMementoMori.s.sol";
import {DeployConfig} from "../../../scripts/DeployConfig.s.sol";
import {Test, console} from "../../../lib/forge-std/src/Test.sol";

contract MMTest is Test {
    MementoMori mementoMori;
    DeployConfig deployConfig;
    uint256 fee;
    address router;
    address link;
    uint64 chainSelector;

    MementoMori.Will[] wills;
    address USER = makeAddr("user");

    //Events
    event WillExecuted(address indexed owner);
    event ExecutionRequested(address indexed owner);
    event WillCreated(address indexed owner);
    event WillUpdated(address indexed owner);
    event ExecutionCancelled(address indexed owner);
    event WillDeleted(address indexed owner);

    function setUp() external {
        DeployMementoMori deployer = new DeployMementoMori();
        (mementoMori, deployConfig) = deployer.run();
        (fee, router, link, chainSelector) = deployConfig.activeConfig();
        vm.deal(USER, 1 ether);
    }

    function testInitializesWithValues() public view {
        assert(mementoMori.fee() == fee);

        assert(mementoMori.chainSelector() == chainSelector);
    }

    function testRevertWhenyuDontPayenough() public {
        vm.expectRevert();
        mementoMori.saveWillHash(wills, 0);
    }

    function testWillHashSaved() public {
        vm.prank(USER);
        mementoMori.saveWillHash{value: 1}(wills, 0);
        assert(keccak256(abi.encode(wills)) == mementoMori.willHashes(USER));
    }

    function testEmitWillCreated() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false);
        emit WillCreated(USER);
        mementoMori.saveWillHash{value: 1}(wills, 0);
    }

    function testEmitWillUpdated() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false);
        emit WillUpdated(USER);
        mementoMori.saveWillHash{value: 1}(wills, 1);
    }

    function testEmitExecutionCancelled() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false);
        emit ExecutionCancelled(USER);
        mementoMori.saveWillHash{value: 1}(wills, 2);
    }

    function testDeleteWill() public {
        vm.prank(USER);
        mementoMori.deleteWill();
        assert(bytes32(0) == mementoMori.willHashes(USER));
    }

    function testEmitWillDeleted() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false);
        emit WillDeleted(USER);
        mementoMori.deleteWill();
    }

    function testRequestExecutuion() public {
        vm.prank(USER);
        mementoMori.saveWillHash{value: 1}(wills, 0);
        wills[0].isActive = true;
        mementoMori.requestExecution(wills);
        assert(keccak256(abi.encode(wills)) == mementoMori.willHashes(USER));
    }
}
