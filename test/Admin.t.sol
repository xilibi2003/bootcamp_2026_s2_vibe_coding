// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Admin} from "../src/Admin.sol";
import {Bank} from "../src/Bank.sol";

contract AdminBankHarness is Bank {
    function exposeTransferAdmin(address newAdmin) external {
        _transferAdmin(newAdmin);
    }
}

contract AdminTest is Test {
    AdminBankHarness internal bank;
    Admin internal adminContract;

    address internal alice = address(0xA11CE);
    address internal outsider = address(0x0A751DE);

    function setUp() public {
        bank = new AdminBankHarness();
        adminContract = new Admin();

        vm.deal(alice, 5 ether);
        vm.deal(outsider, 5 ether);
    }

    function testOwnerCanWithdrawFromManagedBank() public {
        vm.prank(alice);
        bank.deposit{value: 2 ether}();

        bank.exposeTransferAdmin(address(adminContract));

        uint256 adminBalanceBefore = address(adminContract).balance;
        adminContract.adminWithdraw(bank);

        assertEq(address(bank).balance, 0);
        assertEq(address(adminContract).balance, adminBalanceBefore + 2 ether);
    }

    function testAdminWithdrawRequiresOwner() public {
        bank.exposeTransferAdmin(address(adminContract));

        vm.expectRevert("Admin: caller is not owner");
        vm.prank(outsider);
        adminContract.adminWithdraw(bank);
    }

    function testAdminWithdrawRequiresManagedBank() public {
        vm.expectRevert("Admin: contract is not bank admin");
        adminContract.adminWithdraw(bank);
    }
}

