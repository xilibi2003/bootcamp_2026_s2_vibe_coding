// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {TokenBankUpkeep} from "../src/TokenBankUpkeep.sol";

contract TokenBankUpkeepTest is Test {
    MyPermitToken internal token;
    TokenBank internal tokenBank;
    TokenBankUpkeep internal upkeep;

    address internal alice = address(0xABC);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new MyPermitToken();
        tokenBank = new TokenBank(address(token));
        upkeep = new TokenBankUpkeep(address(tokenBank));

        // Transfer some tokens to Alice and Bob for depositing
        assertTrue(token.transfer(alice, 1_000 ether));
        assertTrue(token.transfer(bob, 500 ether));
    }

    function testCheckUpkeepFalseWhenBalanceLow() public {
        // Alice deposits exactly 100 tokens
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 100 ether));
        vm.prank(alice);
        tokenBank.deposit(100 ether);

        (bool upkeepNeeded, ) = upkeep.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepTrueWhenBalanceHigh() public {
        // Alice deposits 100.01 tokens
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 100.01 ether));
        vm.prank(alice);
        tokenBank.deposit(100.01 ether);

        (bool upkeepNeeded, ) = upkeep.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeepRevertsWhenBalanceLow() public {
        // Alice deposits 90 tokens
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 90 ether));
        vm.prank(alice);
        tokenBank.deposit(90 ether);

        vm.expectRevert("TokenBankUpkeep: balance must be greater than 100 tokens");
        upkeep.performUpkeep("");
    }

    function testPerformUpkeepSucceedsWhenBalanceHigh() public {
        // Alice deposits 120 tokens
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 120 ether));
        vm.prank(alice);
        tokenBank.deposit(120 ether);

        uint256 adminBalanceBefore = token.balanceOf(address(this));

        // Call performUpkeep (should succeed)
        upkeep.performUpkeep("");

        // 120 ether / 2 = 60 ether remains in the bank
        assertEq(token.balanceOf(address(tokenBank)), 60 ether);

        // 60 ether transferred to the admin (address(this))
        assertEq(
            token.balanceOf(address(this)),
            adminBalanceBefore + 60 ether
        );
    }
}
