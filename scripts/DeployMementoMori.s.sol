// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MementoMori} from "../contracts/MementoMori.sol";
import {DeployConfig} from "./DeployConfig.s.sol";

contract DeployMementoMori is Script {
    function run() external returns (MementoMori, DeployConfig) {
        DeployConfig deployConfig = new DeployConfig();
        (
            uint256 fee,
            address router,
            address link,
            uint64 chainSelector
        ) = deployConfig.activeConfig();
        vm.startBroadcast();
        MementoMori mementoMori = new MementoMori(
            fee,
            router,
            link,
            chainSelector
        );
        vm.stopBroadcast();
        return (mementoMori, deployConfig);
    }
}
