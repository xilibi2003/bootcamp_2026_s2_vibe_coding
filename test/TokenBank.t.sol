// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract TokenBankTest is Test {
    MyToken internal token;
    TokenBank internal tokenBank;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new MyToken();
        tokenBank = new TokenBank(address(token));

        assertTrue(token.transfer(alice, 1_000 ether));
        assertTrue(token.transfer(bob, 500 ether));
    }

    function testDepositPullsTokensIntoBank() public {
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 300 ether));

        vm.prank(alice);
        tokenBank.deposit(300 ether);

        assertEq(token.balanceOf(address(tokenBank)), 300 ether);
        assertEq(tokenBank.depositedAmount(alice), 300 ether);
    }

    function testWithdrawRequiresAdmin() public {
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 100 ether));

        vm.prank(alice);
        tokenBank.deposit(100 ether);

        vm.expectRevert("TokenBank: caller is not admin");
        vm.prank(alice);
        tokenBank.withdraw();
    }

    function testWithdrawTransfersAllTokensToAdmin() public {
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 200 ether));
        vm.prank(alice);
        tokenBank.deposit(200 ether);

        vm.prank(bob);
        assertTrue(token.approve(address(tokenBank), 50 ether));
        vm.prank(bob);
        tokenBank.deposit(50 ether);

        uint256 adminBalanceBefore = token.balanceOf(address(this));
        tokenBank.withdraw();

        assertEq(token.balanceOf(address(tokenBank)), 0);
        assertEq(token.balanceOf(address(this)), adminBalanceBefore + 250 ether);
    }
}
