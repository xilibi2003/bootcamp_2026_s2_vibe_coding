// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {MockPermit2} from "../src/MockPermit2.sol";

contract DeployTokenBankScript is Script {
    function run() external returns (MyPermitToken token, TokenBank tokenBank) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy and etch MockPermit2 at the standard Uniswap Permit2 address
        MockPermit2 mockPermit2 = new MockPermit2();
        vm.etch(0x000000000022D473030F116dDEE9F6B43aC78BA3, address(mockPermit2).code);
        
        token = new MyPermitToken();
        tokenBank = new TokenBank(address(token));
        vm.stopBroadcast();
    }
}
