// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Admin} from "../src/Admin.sol";
import {Bank, BigBank} from "../src/Bank.sol";

contract DeployBankScript is Script {
    function run()
        external
        returns (Bank bank, BigBank bigBank, Admin adminContract)
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        bank = new Bank();
        bigBank = new BigBank();
        adminContract = new Admin();
        vm.stopBroadcast();
    }
}

