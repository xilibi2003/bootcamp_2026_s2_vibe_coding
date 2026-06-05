// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {NMTNFT} from "../src/MyERC721.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import "forge-std/console.sol";

contract DeployNFTMarketUpgradeable is BaseScript {
    function setUp() public override {
        super.setUp();
    }

    function run() external broadcaster returns (address marketProxy) {
        // 1. Deploy MyPermitToken
        MyPermitToken token = new MyPermitToken();
        console.log("MyPermitToken deployed at:", address(token));
        saveContract("MyPermitToken", address(token));

        // 2. Deploy NMTNFT Proxy
        bytes memory nftInitData = abi.encodeWithSelector(
            NMTNFT.initialize.selector,
            deployer
        );
        address nftProxy = Upgrades.deployUUPSProxy(
            "MyERC721.sol:NMTNFT",
            nftInitData
        );
        console.log("NMTNFT UUPS Proxy deployed at:", nftProxy);
        saveContract("NMTNFT", nftProxy);

        // 3. Deploy NFTMarket Proxy
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            address(token),
            nftProxy,
            deployer
        );
        marketProxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            marketInitData
        );
        console.log("NFTMarket UUPS Proxy deployed at:", marketProxy);
        saveContract("NFTMarketUpgradeable", marketProxy);
    }
}
