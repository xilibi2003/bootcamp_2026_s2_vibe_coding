// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract DepositTokenBankScript is Script {
    function run() external {
        vm.startBroadcast();

        // 自动读取当前链上已部署的 TokenBank 地址
        address tokenBankAddress = readDeploymentAddress("tokenbank");
        TokenBank tokenBank = TokenBank(tokenBankAddress);
        IERC20 token = IERC20(0xBB071027a43E131AA03Aaa6B16Eac025bAaaa0e4);

        uint256 depositAmount = 10 * 10 ** 18; // 100 tokens

        // 1. 授权 TokenBank 合约使用代币
        console.log("Approving TokenBank to spend 100 tokens...");
        token.approve(address(tokenBank), depositAmount);

        // 2. 存入代币到 TokenBank 合约中
        console.log("Depositing 100 tokens into TokenBank...");
        tokenBank.deposit(depositAmount);

        console.log("Deposit successful!");
        console.log(
            "New TokenBank balance:",
            token.balanceOf(address(tokenBank))
        );

        vm.stopBroadcast();
    }

    function readDeploymentAddress(
        string memory name
    ) internal view returns (address) {
        string memory chainId = vm.toString(block.chainid);
        string memory path = string.concat(
            "deployments/",
            string.concat(
                name,
                string.concat("_", string.concat(chainId, ".json"))
            )
        );
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, ".address");
    }
}
