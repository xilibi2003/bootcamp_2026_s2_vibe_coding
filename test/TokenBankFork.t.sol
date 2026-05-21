// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Test} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract TokenBankForkTest is Test {
    using SafeERC20 for IERC20;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant DEFAULT_USDT_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    uint256 internal constant USDT_DECIMALS = 1e6;

    IERC20 internal usdt;
    TokenBank internal tokenBank;
    address internal usdtWhale;

    address internal alice = address(0xA11CE);

    function setUp() public {
        string memory mainnetRpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        require(bytes(mainnetRpcUrl).length != 0, "set MAINNET_RPC_URL");

        uint256 forkBlock = vm.envOr("MAINNET_FORK_BLOCK", uint256(0));

        if (forkBlock == 0) {
            vm.createSelectFork(mainnetRpcUrl);
        } else {
            vm.createSelectFork(mainnetRpcUrl, forkBlock);
        }

        usdt = IERC20(USDT);
        tokenBank = new TokenBank(USDT);
        usdtWhale = vm.envOr("USDT_WHALE", DEFAULT_USDT_WHALE);
    }

    function testDepositMainnetForkUsdt() public {
        uint256 startingBalance = 1_000 * USDT_DECIMALS;
        uint256 depositAmount = 250 * USDT_DECIMALS;

        assertGe(usdt.balanceOf(usdtWhale), startingBalance);

        vm.prank(usdtWhale);
        usdt.safeTransfer(alice, startingBalance);

        vm.startPrank(alice);
        usdt.forceApprove(address(tokenBank), depositAmount);
        tokenBank.deposit(depositAmount);
        vm.stopPrank();

        assertEq(usdt.balanceOf(alice), startingBalance - depositAmount);
        assertEq(usdt.balanceOf(address(tokenBank)), depositAmount);
        assertEq(tokenBank.depositedAmount(alice), depositAmount);
    }
}
