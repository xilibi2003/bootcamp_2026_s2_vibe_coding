// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployTokenBankScript is Script {
    function run() external returns (MyToken token, TokenBank tokenBank) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        token = new MyToken();
        tokenBank = new TokenBank(address(token));
        vm.stopBroadcast();
    }
}
