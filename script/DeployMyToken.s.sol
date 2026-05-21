// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyTokenScript is Script {
    function run() external returns (MyToken token) {
        vm.startBroadcast();
        token = new MyToken("ETT");
        vm.stopBroadcast();
    }
}
