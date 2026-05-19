// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Admin} from "../src/Admin.sol";
import {Bank, BigBank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank internal bank;
    BigBank internal bigBank;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA401);
    address internal outsider = address(0x0A751DE);

    receive() external payable {}

    function setUp() public {
        bank = new Bank();
        bigBank = new BigBank();

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        vm.deal(outsider, 10 ether);
    }

    function testBankDepositTracksBalancesAndTopDepositors() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.prank(bob);
        bank.deposit{value: 3 ether}();

        vm.prank(carol);
        bank.deposit{value: 2 ether}();

        vm.prank(alice);
        bank.deposit{value: 4 ether}();

        address[3] memory topDepositors = bank.getTopDepositors();

        assertEq(bank.balances(alice), 5 ether);
        assertEq(bank.balances(bob), 3 ether);
        assertEq(bank.balances(carol), 2 ether);
        assertEq(topDepositors[0], alice);
        assertEq(topDepositors[1], bob);
        assertEq(topDepositors[2], carol);
    }

    function testBankWithdrawRequiresAdmin() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.expectRevert("Bank: caller is not admin");
        vm.prank(alice);
        bank.withdraw();
    }

    function testBankWithdrawTransfersEthToAdmin() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.prank(bob);
        bank.deposit{value: 2 ether}();

        uint256 balanceBefore = address(this).balance;
        bank.withdraw();

        assertEq(address(bank).balance, 0);
        assertEq(address(this).balance, balanceBefore + 3 ether);
    }

    function testBigBankRejectsSmallDeposit() public {
        vm.expectRevert("BigBank: deposit amount must exceed 0.001 ether");
        vm.prank(alice);
        bigBank.deposit{value: 0.001 ether}();
    }

    function testBigBankAcceptsLargeDeposit() public {
        vm.prank(alice);
        bigBank.deposit{value: 0.002 ether}();

        assertEq(bigBank.balances(alice), 0.002 ether);
    }

    function testBigBankSupportsAdminTransfer() public {
        bigBank.transferAdmin(alice);

        assertEq(bigBank.admin(), alice);

        vm.prank(outsider);
        vm.expectRevert("Bank: caller is not admin");
        bigBank.transferAdmin(bob);
    }
}
