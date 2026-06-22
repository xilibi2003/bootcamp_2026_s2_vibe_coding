// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {KKToken} from "../src/KKToken.sol";

contract StakingPoolTest is Test {
    StakingPool public pool;
    KKToken public token;

    address public alice = address(0x1111);
    address public bob = address(0x2222);

    function setUp() public {
        pool = new StakingPool();
        token = pool.kkToken();

        // Give Alice and Bob some ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function test_Deposit() public {
        // Alice deposits 10 ETH
        vm.prank(alice);
        pool.deposit{value: 10 ether}();

        assertEq(pool.totalStaked(), 10 ether);
        (uint256 amount, uint256 rewardDebt) = pool.userInfo(alice);
        assertEq(amount, 10 ether);
        assertEq(rewardDebt, 0);
    }

    function test_RewardAccumulation() public {
        // Alice deposits 10 ETH at block N
        uint256 startBlock = block.number;
        vm.prank(alice);
        pool.deposit{value: 10 ether}();

        // Roll 5 blocks
        vm.roll(startBlock + 5);

        // Pending should be 5 * 10 = 50 KKToken
        uint256 pending = pool.pendingKK(alice);
        assertEq(pending, 50 * 1e18);
    }

    function test_Claim() public {
        uint256 startBlock = block.number;
        vm.prank(alice);
        pool.deposit{value: 10 ether}();

        // Roll 10 blocks
        vm.roll(startBlock + 10);

        // Alice claims rewards
        vm.prank(alice);
        pool.claim();

        // Alice should receive 100 KKToken
        assertEq(token.balanceOf(alice), 100 * 1e18);

        // Pending should be 0 immediately after claim
        assertEq(pool.pendingKK(alice), 0);
    }

    function test_Withdraw() public {
        uint256 startBlock = block.number;
        vm.prank(alice);
        pool.deposit{value: 10 ether}();

        // Roll 10 blocks
        vm.roll(startBlock + 10);

        uint256 ethBalanceBefore = alice.balance;

        // Alice withdraws 4 ETH
        vm.prank(alice);
        pool.withdraw(4 ether);

        // Alice should receive 4 ETH back and 100 KKToken
        assertEq(alice.balance, ethBalanceBefore + 4 ether);
        assertEq(token.balanceOf(alice), 100 * 1e18);

        // Verify remaining amount
        (uint256 amount, ) = pool.userInfo(alice);
        assertEq(amount, 6 ether);
        assertEq(pool.totalStaked(), 6 ether);
    }

    function test_FairAllocation_TwoUsers() public {
        // Block 0: Start block is current block
        uint256 startBlock = block.number;

        // Alice deposits 10 ETH
        vm.prank(alice);
        pool.deposit{value: 10 ether}();

        // Roll to block 10 (10 blocks passed, Alice has been the sole staker)
        vm.roll(startBlock + 10);

        // At block 10, Bob deposits 10 ETH.
        // Before Bob's deposit, Alice's pending is harvested since it updates the pool.
        // Let's verify Alice's reward.
        // Alice should have 10 blocks * 10 KK = 100 KK token.
        assertEq(pool.pendingKK(alice), 100 * 1e18);
        assertEq(pool.pendingKK(bob), 0);

        vm.prank(bob);
        pool.deposit{value: 10 ether}(); // Bob deposits at block 10

        // Roll to block 20 (10 more blocks passed).
        // During block 10 to 20, Alice and Bob each have 10 ETH staked (total 20 ETH).
        // Total reward generated: 10 blocks * 10 KK = 100 KK.
        // Each should get 50 KK.
        // So Alice pending = 100 + 50 = 150 KK.
        // Bob pending = 50 KK.
        vm.roll(startBlock + 20);

        assertEq(pool.pendingKK(alice), 150 * 1e18);
        assertEq(pool.pendingKK(bob), 50 * 1e18);

        // Alice claims rewards
        vm.prank(alice);
        pool.claim();
        assertEq(token.balanceOf(alice), 150 * 1e18);

        // Bob withdraws all ETH
        vm.prank(bob);
        pool.withdraw(10 ether);
        assertEq(token.balanceOf(bob), 50 * 1e18);
        assertEq(bob.balance, 100 ether); // Bob gets his 10 ETH back
    }

    function test_DirectDepositViaReceive() public {
        uint256 startBlock = block.number;
        
        // Send ETH directly to the contract (should stake it)
        vm.prank(alice);
        (bool success, ) = address(pool).call{value: 10 ether}("");
        assertTrue(success);

        assertEq(pool.totalStaked(), 10 ether);
        (uint256 amount, ) = pool.userInfo(alice);
        assertEq(amount, 10 ether);

        vm.roll(startBlock + 5);
        assertEq(pool.pendingKK(alice), 50 * 1e18);
    }
}
