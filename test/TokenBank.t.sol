// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {MockPermit2} from "../src/MockPermit2.sol";

contract TokenBankTest is Test {
    MyPermitToken internal token;
    TokenBank internal tokenBank;
    MockPermit2 internal mockPermit2;

    address internal constant PERMIT2_ADDRESS =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;

    uint256 internal alicePrivateKey = 0x1111;
    address internal alice;
    address internal bob = address(0xB0B);

    function setUp() public {
        alice = vm.addr(alicePrivateKey);

        // Deploy and etch MockPermit2
        mockPermit2 = new MockPermit2();
        vm.etch(PERMIT2_ADDRESS, address(mockPermit2).code);

        token = new MyPermitToken();
        tokenBank = new TokenBank(address(token));

        assertTrue(token.transfer(alice, 1_000 ether));
        assertTrue(token.transfer(bob, 500 ether));
    }

    function testTokenMetadata() public view {
        assertEq(token.name(), "MyPermitToken");
        assertEq(token.symbol(), "MPT2");
        assertEq(token.totalSupply(), 100_000 ether);
    }

    function testDepositPullsTokensIntoBank() public {
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 300 ether));

        vm.prank(alice);
        tokenBank.deposit(300 ether);

        assertEq(token.balanceOf(address(tokenBank)), 300 ether);
        assertEq(tokenBank.depositedAmount(alice), 300 ether);
    }

    function testDepositWithPermit2Success() public {
        uint256 amount = 150 ether;
        uint256 nonce = 42;
        uint256 deadline = block.timestamp + 3600;

        // 1. Alice approves Permit2 to spend her tokens (required for Permit2)
        vm.prank(alice);
        token.approve(PERMIT2_ADDRESS, type(uint256).max);

        // 2. Generate EIP-712 Permit2 signature for TokenBank as spender
        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                mockPermit2.TOKEN_PERMISSIONS_TYPEHASH(),
                address(token),
                amount
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                mockPermit2.PERMIT_TRANSFER_FROM_TYPEHASH(),
                tokenPermissionsHash,
                address(tokenBank),
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                MockPermit2(PERMIT2_ADDRESS).domainSeparator(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 3. Deposit via permit2
        vm.prank(alice);
        tokenBank.depositWithPermit2(amount, nonce, deadline, signature);

        // Verify deposit state
        assertEq(token.balanceOf(address(tokenBank)), amount);
        assertEq(tokenBank.depositedAmount(alice), amount);
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
        assertEq(
            token.balanceOf(address(this)),
            adminBalanceBefore + 250 ether
        );
    }

    function testCollectRevertsIfBalanceTooLow() public {
        // Alice deposits exactly 100 ether (100 * 10**18)
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 100 ether));
        vm.prank(alice);
        tokenBank.deposit(100 ether);

        vm.expectRevert("TokenBank: balance must be greater than 100 tokens");
        tokenBank.collect();
    }

    function testCollectSucceedsIfBalanceAboveThreshold() public {
        // Alice deposits 101 ether (101 * 10**18)
        vm.prank(alice);
        assertTrue(token.approve(address(tokenBank), 101 ether));
        vm.prank(alice);
        tokenBank.deposit(101 ether);

        uint256 adminBalanceBefore = token.balanceOf(address(this));

        // Anyone can call collect()
        vm.prank(bob);
        tokenBank.collect();

        // 101 ether / 2 = 50.5 ether
        assertEq(token.balanceOf(address(tokenBank)), 50.5 ether);
        assertEq(
            token.balanceOf(address(this)),
            adminBalanceBefore + 50.5 ether
        );
    }
}
