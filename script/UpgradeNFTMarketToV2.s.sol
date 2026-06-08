// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NFTMarket_V2} from "../src/NFTMarket_V2.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import "forge-std/console.sol";

contract UpgradeNFTMarketToV2 is BaseScript {
    function setUp() public override {
        super.setUp();
    }

    function run() external broadcaster returns (address proxy) {
        // 1. Read existing NFTMarket proxy address
        address existingProxy = readDeploymentAddress("NFTMarketUpgradeable");
        console.log("Existing NFTMarket Proxy address:", existingProxy);

        // 2. Perform upgrade and run initializeV2
        Options memory opts;
        opts.unsafeAllow = "missing-initializer-call,incorrect-initializer-order";
        Upgrades.upgradeProxy(
            existingProxy,
            "NFTMarket_V2.sol:NFTMarket_V2",
            abi.encodeCall(NFTMarket_V2.initializeV2, ()),
            opts
        );

        console.log("NFTMarket successfully upgraded to V2!");
        proxy = existingProxy;
    }

    function readDeploymentAddress(string memory name) internal view returns (address) {
        string memory chainId = vm.toString(block.chainid);
        string memory path = string.concat(
            "deployments/",
            string.concat(name, string.concat("_", string.concat(chainId, ".json")))
        );
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, ".address");
    }
}
