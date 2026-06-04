// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MyWallet} from "../src/MyWallet.sol";

contract MyWalletTest is Test {
    MyWallet internal wallet;
    address internal owner = address(0xA11CE);
    address internal newOwner = address(0xB0B);

    function setUp() public {
        vm.prank(owner);
        wallet = new MyWallet("MyTestWallet");
    }

    function testConstructorSetsOwner() public view {
        assertEq(wallet.owner(), owner);
        assertEq(wallet.name(), "MyTestWallet");
    }

    function testTransferOwnershipSuccess() public {
        vm.prank(owner);
        wallet.transferOwernship(newOwner);
        assertEq(wallet.owner(), newOwner);
    }

    function testTransferOwnershipRequiresAuth() public {
        vm.prank(newOwner);
        vm.expectRevert("Not authorized");
        wallet.transferOwernship(newOwner);
    }

    function testTransferOwnershipRejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("New owner is the zero address");
        wallet.transferOwernship(address(0));
    }

    function testTransferOwnershipRejectsSameOwner() public {
        vm.prank(owner);
        vm.expectRevert("New owner is the same as the old owner");
        wallet.transferOwernship(owner);
    }
}
