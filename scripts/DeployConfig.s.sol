// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MementoMori} from "../contracts/MementoMori.sol";

contract DeployConfig is Script {
    struct Config {
        uint256 fee;
        address router;
        address link;
        uint64 chainSelector;
    }
    Config public activeConfig;

    constructor() {
        if (block.chainid == 1115511) {
            activeConfig = getEthSepoliaConfig();
        } else {
            activeConfig = getBaseSepoliaConfig();
        }
    }

    function getEthSepoliaConfig() public pure returns (Config memory) {
        return
            Config({
                fee: 1,
                router: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                chainSelector: 16015286601757825753
            });
    }

    function getBaseSepoliaConfig() public pure returns (Config memory) {
        return
            Config({
                fee: 1,
                router: 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
                link: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
                chainSelector: 10344971235874465080
            });
    }
}
