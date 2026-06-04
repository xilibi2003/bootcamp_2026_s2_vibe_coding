// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";
import "forge-std/console.sol";

contract DeployMyTokenScript is Script {
    function run() external returns (MyToken token, TokenBank tokenbank) {
        vm.startBroadcast();
        token = new MyToken("ETT");
        tokenbank = new TokenBank(address(token));

        console.log("token: %s", address(token));
        saveContract("ETT", address(token));

        console.log("tokenbank: %s", address(tokenbank));
        saveContract("tokenbank", address(tokenbank));

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
