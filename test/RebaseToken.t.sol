// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken internal token;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        token = new RebaseToken("Rebase Deflationary Token", "RDT");
    }

    function testInitialSupply() public view {
        uint256 expectedSupply = 10_000_000 * 10**18;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(address(this)), expectedSupply);
        assertEq(token.decimals(), 18);
        assertEq(token.name(), "Rebase Deflationary Token");
        assertEq(token.symbol(), "RDT");
    }

    function testNoDeflationBeforeOneYear() public {
        // Warp to 364 days (just under a year)
        uint256 initialTime = block.timestamp;
        vm.warp(initialTime + 364 days);

        uint256 expectedSupply = 10_000_000 * 10**18;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(address(this)), expectedSupply);

        // Call rebase and check that it doesn't change anything
        token.rebase();
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.lastRebaseTime(), initialTime);
    }

    function testDeflationAfterOneYear() public {
        uint256 initialTime = block.timestamp;
        // Warp exactly 1 year
        vm.warp(initialTime + 365 days);

        // 1% of 10,000,000 is 100,000. New supply should be 9,900,000.
        uint256 expectedSupply = 9_900_000 * 10**18;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(address(this)), expectedSupply);

        // Call rebase to commit the change to storage
        uint256 returnedSupply = token.rebase();
        assertEq(returnedSupply, expectedSupply);
        assertEq(token.lastRebaseTime(), initialTime + 365 days);

        // Verify that another call to rebase immediately doesn't decrease it further
        token.rebase();
        assertEq(token.totalSupply(), expectedSupply);
    }

    function testDeflationAfterTwoYears() public {
        uint256 initialTime = block.timestamp;
        // Warp exactly 2 years
        vm.warp(initialTime + 730 days);

        // 1st year: 10,000,000 * 0.99 = 9,900,000
        // 2nd year: 9,900,000 * 0.99 = 9,801,000
        uint256 expectedSupply = 9_801_000 * 10**18;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(address(this)), expectedSupply);

        // Commit rebase
        token.rebase();
        assertEq(token.lastRebaseTime(), initialTime + 730 days);
    }

    function testTransferKeepSharesProportion() public {
        // Transfer 1,000,000 tokens to Alice
        uint256 transferAmount = 1_000_000 * 10**18;
        assertTrue(token.transfer(alice, transferAmount));

        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.balanceOf(address(this)), 9_000_000 * 10**18);

        // Warp 1 year (supply decreases by 1%)
        vm.warp(block.timestamp + 365 days);

        // Alice balance should be 990,000 (1,000,000 * 0.99)
        // This address's balance should be 8,910,000 (9,000,000 * 0.99)
        assertEq(token.balanceOf(alice), 990_000 * 10**18);
        assertEq(token.balanceOf(address(this)), 8_910_000 * 10**18);
        assertEq(token.totalSupply(), 9_900_000 * 10**18);

        // Alice transfers all her balance to Bob
        vm.prank(alice);
        assertTrue(token.transfer(bob, 990_000 * 10**18));

        // Alice should have exactly 0 tokens and 0 shares
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.tokenToShares(token.balanceOf(alice)), 0);

        // Bob should have the full 990,000 tokens
        assertEq(token.balanceOf(bob), 990_000 * 10**18);
    }

    function testTransferFromAndAllowance() public {
        uint256 approveAmount = 500_000 * 10**18;
        token.approve(alice, approveAmount);
        assertEq(token.allowance(address(this), alice), approveAmount);

        // Alice transfers on behalf of this contract to Bob
        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, approveAmount));

        assertEq(token.balanceOf(bob), approveAmount);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function testRevertTransferExceedsBalance() public {
        uint256 balance = token.balanceOf(address(this));
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(alice, balance + 1);
    }

    function testRevertTransferFromExceedsAllowance() public {
        uint256 approveAmount = 100 * 10**18;
        token.approve(alice, approveAmount);

        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient allowance");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(address(this), bob, approveAmount + 1);
    }
}
