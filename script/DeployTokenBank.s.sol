// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {TokenBankUpkeep} from "../src/TokenBankUpkeep.sol";
import "forge-std/console.sol";

contract DeployTokenBankScript is Script {
    function run() external returns (TokenBank tokenBank, TokenBankUpkeep upkeep) {
        vm.startBroadcast();

        address token = 0xBB071027a43E131AA03Aaa6B16Eac025bAaaa0e4;

        tokenBank = new TokenBank(token);
        console.log("TokenBank deployed at:", address(tokenBank));
        saveContract("tokenbank", address(tokenBank));

        upkeep = new TokenBankUpkeep(address(tokenBank));
        console.log("TokenBankUpkeep deployed at:", address(upkeep));
        saveContract("tokenbank_upkeep", address(upkeep));

        vm.stopBroadcast();
    }

    function saveContract(string memory name, address addr) public {
        string memory chainId = vm.toString(block.chainid);

        string memory json1 = "key";
        string memory finalJson = vm.serializeAddress(json1, "address", addr);
        string memory dirPath = string.concat(
            string.concat("deployments/", name),
            "_"
        );
        vm.writeJson(
            finalJson,
            string.concat(dirPath, string.concat(chainId, ".json"))
        );
    }
}
