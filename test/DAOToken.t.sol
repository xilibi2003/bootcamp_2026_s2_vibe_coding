// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DAOToken} from "../src/DAOToken.sol";

contract DAOTokenTest is Test {
    DAOToken public token;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    uint256 public ownerPrivateKey;
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;

    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        ownerPrivateKey = 0x1111;
        alicePrivateKey = 0x2222;
        bobPrivateKey = 0x3333;

        owner = vm.addr(ownerPrivateKey);
        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);

        // Deploy DAOToken as owner
        vm.prank(owner);
        token = new DAOToken("DAO Token", "DAO", INITIAL_SUPPLY);
    }

    // 1. Basic Initialization Tests
    function testMetadata() public view {
        assertEq(token.name(), "DAO Token");
        assertEq(token.symbol(), "DAO");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
    }

    // 2. Minting and Burning Tests
    function testMintSuccessful() public {
        uint256 mintAmount = 500_000 * 10**18;
        vm.prank(owner);
        token.mint(alice, mintAmount);

        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function testMintFailNonOwner() public {
        uint256 mintAmount = 500_000 * 10**18;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice)
        );
        token.mint(bob, mintAmount);
    }

    // 3. Voting & Delegation Tests
    function testVotingPowerDelegation() public {
        // Initial voting power is 0 because voting is opt-in (no delegation active yet)
        assertEq(token.getVotes(owner), 0);

        // Owner delegates voting units to themselves
        vm.prank(owner);
        token.delegate(owner);
        assertEq(token.getVotes(owner), INITIAL_SUPPLY);

        // Transfer tokens to Alice
        uint256 transferAmount = 100_000 * 10**18;
        vm.prank(owner);
        assertTrue(token.transfer(alice, transferAmount));

        // Owner's voting power should decrease
        assertEq(token.getVotes(owner), INITIAL_SUPPLY - transferAmount);
        // Alice's voting power is 0 because Alice hasn't delegated
        assertEq(token.getVotes(alice), 0);

        // Alice delegates to herself
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), transferAmount);
    }

    // 4. Past Votes & Checkpoints Test (vm.roll)
    function testPastVotesCheckpoints() public {
        // Start block
        uint256 startBlock = block.number; // e.g., 1

        vm.prank(owner);
        token.delegate(owner);

        // Transfer 100 tokens to Alice at block 1
        uint256 amount = 100 * 10**18;
        vm.prank(owner);
        assertTrue(token.transfer(alice, amount));

        // Roll block forward
        vm.roll(startBlock + 5); // block 6
        
        // Alice delegates to Alice at block 6
        vm.prank(alice);
        token.delegate(alice);

        // Roll block forward again
        vm.roll(startBlock + 10); // block 11

        // Check past votes (validate block constraints: timepoint < currentBlock)
        // At block 5 (before Alice delegated), Alice's votes should be 0
        assertEq(token.getPastVotes(alice, startBlock + 4), 0);
        // At block 6 (when Alice delegated), Alice's votes should be amount
        // But to query block 6, the current block must be > 6, which it is (11)
        assertEq(token.getPastVotes(alice, startBlock + 5), amount);
        assertEq(token.getPastVotes(alice, startBlock + 9), amount);

        // Owner's votes at block 0/1 (before transfer or delegation checkpoint took effect)
        // getPastVotes will revert if we query startBlock + 10 because block.number is startBlock + 10
        // But we can query startBlock + 9
        assertEq(token.getPastVotes(owner, startBlock + 9), INITIAL_SUPPLY - amount);
    }

    // 5. ERC20Permit Tests (Signature Verification)
    function testPermitSignature() public {
        address spender = bob;
        uint256 value = 50_000 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(alice);

        // Construct struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                spender,
                value,
                nonce,
                deadline
            )
        );

        // Hashing with EIP-712 Domain Separator
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign the digest with Alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Execute Permit
        token.permit(alice, spender, value, deadline, v, r, s);

        // Verify Allowance
        assertEq(token.allowance(alice, spender), value);
        // Verify Nonce Incremented
        assertEq(token.nonces(alice), nonce + 1);
    }

    // 6. ERC20Votes delegateBySig Tests (Signature Verification)
    function testDelegateBySig() public {
        address delegatee = bob;
        uint256 nonce = token.nonces(alice);
        uint256 expiry = block.timestamp + 1 hours;

        // Construct struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)"),
                delegatee,
                nonce,
                expiry
            )
        );

        // Hashing with EIP-712 Domain Separator
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign with Alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Send tokens to Alice first so Alice has voting weight
        uint256 amount = 10_000 * 10**18;
        vm.prank(owner);
        assertTrue(token.transfer(alice, amount));

        // Bob should have 0 votes from Alice initially
        assertEq(token.getVotes(bob), 0);

        // Execute delegation by signature
        token.delegateBySig(delegatee, nonce, expiry, v, r, s);

        // Bob should now have Alice's voting weight
        assertEq(token.delegates(alice), bob);
        assertEq(token.getVotes(bob), amount);
        // Verify Alice's nonce incremented
        assertEq(token.nonces(alice), nonce + 1);
    }
}
