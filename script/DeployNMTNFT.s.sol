// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NMTNFT} from "../src/MyERC721.sol";
import "forge-std/console.sol";

contract DeployNMTNFT is BaseScript {
    function setUp() public override {
        super.setUp();
    }

    function run() external broadcaster returns (address proxy) {
        bytes memory initData = abi.encodeWithSelector(
            NMTNFT.initialize.selector,
            deployer
        );

        proxy = Upgrades.deployUUPSProxy(
            "MyERC721.sol:NMTNFT",
            initData
        );

        console.log("NMTNFT UUPS Proxy deployed at: %s", proxy);
        saveContract("NMTNFT", proxy);
    }
}
