// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../../../lib/forge-std/src/Script.sol";
import {MementoMori} from "../../../contracts/MementoMori.sol";
import {DeployMementoMori} from "../../../scripts/DeployMementoMori.s.sol";
import {DeployConfig} from "../../../scripts/DeployConfig.s.sol";
import {Test, console} from "../../../lib/forge-std/src/Test.sol";

contract MMTEst is Test {
    MementoMori mementoMori;
    DeployConfig deployConfig;
    uint256 fee;
    address router;
    address link;
    uint64 chainSelector;

    function setUp() external {
        DeployMementoMori deployer = new DeployMementoMori();
        (mementoMori, deployConfig) = deployer.run();
        (fee, router, link, chainSelector) = deployConfig.activeConfig();
    }

    function testInitializesWithValues() public view {
        assert(mementoMori.fee() == fee);

        assert(mementoMori.chainSelector() == chainSelector);
    }
}
