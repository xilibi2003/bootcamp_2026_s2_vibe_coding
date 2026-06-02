// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MockTarget {
    event CallReceived(uint256 value, bytes data);
    bool public shouldRevert;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function doSomething() external payable {
        if (shouldRevert) {
            revert("MockTarget: failed intentionally");
        }
        emit CallReceived(msg.value, msg.data);
    }

    receive() external payable {
        if (shouldRevert) {
            revert("MockTarget: failed intentionally");
        }
        emit CallReceived(msg.value, "");
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    MockTarget public target;

    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public nonOwner = address(0x4);

    address[] public initialOwners;

    function setUp() public {
        initialOwners = new address[](3);
        initialOwners[0] = owner1;
        initialOwners[1] = owner2;
        initialOwners[2] = owner3;

        // Deploy 2/3 MultiSigWallet
        wallet = new MultiSigWallet(initialOwners, 2);
        
        // Deploy test target
        target = new MockTarget();

        // Fund wallet
        vm.deal(address(wallet), 10 ether);
    }

    // 1. Constructor Tests
    function test_Constructor_Success() public view {
        assertEq(wallet.requiredConfirmations(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));

        address[] memory ownersList = wallet.getOwners();
        assertEq(ownersList.length, 3);
        assertEq(ownersList[0], owner1);
        assertEq(ownersList[1], owner2);
        assertEq(ownersList[2], owner3);
    }

    function test_Constructor_RevertOnEmptyOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert(MultiSigWallet.InvalidOwners.selector);
        new MultiSigWallet(emptyOwners, 1);
    }

    function test_Constructor_RevertOnInvalidThreshold() public {
        vm.expectRevert(MultiSigWallet.InvalidRequiredConfirmations.selector);
        new MultiSigWallet(initialOwners, 0);

        vm.expectRevert(MultiSigWallet.InvalidRequiredConfirmations.selector);
        new MultiSigWallet(initialOwners, 4);
    }

    function test_Constructor_RevertOnZeroAddressOwner() public {
        address[] memory badOwners = new address[](2);
        badOwners[0] = owner1;
        badOwners[1] = address(0);
        vm.expectRevert(MultiSigWallet.InvalidOwners.selector);
        new MultiSigWallet(badOwners, 1);
    }

    function test_Constructor_RevertOnDuplicateOwner() public {
        address[] memory badOwners = new address[](3);
        badOwners[0] = owner1;
        badOwners[1] = owner2;
        badOwners[2] = owner1; // duplicate
        vm.expectRevert(MultiSigWallet.InvalidOwners.selector);
        new MultiSigWallet(badOwners, 2);
    }

    // 2. Propose Tests
    function test_Propose_Success() public {
        bytes memory data = abi.encodeWithSignature("doSomething()");
        
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, data);

        assertEq(proposalId, 0);
        assertEq(wallet.getProposalsCount(), 1);

        (address to, uint256 value, bytes memory storedData, bool executed, uint256 confirmationsCount) = wallet.proposals(0);
        assertEq(to, address(target));
        assertEq(value, 1 ether);
        assertEq(storedData, data);
        assertEq(executed, false);
        assertEq(confirmationsCount, 1); // proposer auto-confirms

        assertTrue(wallet.isConfirmed(0, owner1));
    }

    function test_Propose_RevertNotOwner() public {
        bytes memory data = "";
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.propose(address(target), 1 ether, data);
    }

    // 3. Confirm Tests
    function test_Confirm_Success() public {
        bytes memory data = abi.encodeWithSignature("doSomething()");
        
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, data);

        vm.prank(owner2);
        wallet.confirm(proposalId);

        (, , , , uint256 confirmationsCount) = wallet.proposals(proposalId);
        assertEq(confirmationsCount, 2);
        assertTrue(wallet.isConfirmed(proposalId, owner2));
    }

    function test_Confirm_RevertNotOwner() public {
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        wallet.confirm(proposalId);
    }

    function test_Confirm_RevertDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.ProposalDoesNotExist.selector);
        wallet.confirm(999);
    }

    function test_Confirm_RevertAlreadyConfirmed() public {
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, "");

        // Proposer already confirmed during propose()
        vm.prank(owner1);
        vm.expectRevert(MultiSigWallet.ProposalAlreadyConfirmed.selector);
        wallet.confirm(proposalId);

        // Confirmation by second owner
        vm.prank(owner2);
        wallet.confirm(proposalId);

        // Double confirmation by second owner
        vm.prank(owner2);
        vm.expectRevert(MultiSigWallet.ProposalAlreadyConfirmed.selector);
        wallet.confirm(proposalId);
    }

    // 4. Execute Tests
    function test_Execute_Success() public {
        bytes memory data = abi.encodeWithSignature("doSomething()");
        
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, data);

        vm.prank(owner2);
        wallet.confirm(proposalId);

        uint256 initialTargetBalance = address(target).balance;

        // Execute can be called by anyone (using nonOwner here)
        vm.prank(nonOwner);
        wallet.execute(proposalId);

        (, , , bool executed, ) = wallet.proposals(proposalId);
        assertTrue(executed);
        assertEq(address(target).balance, initialTargetBalance + 1 ether);
    }

    function test_Execute_RevertThresholdNotMet() public {
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, "");

        // Only 1 confirmation (owner1). Threshold is 2.
        vm.prank(nonOwner);
        vm.expectRevert(MultiSigWallet.ConfirmationsThresholdNotMet.selector);
        wallet.execute(proposalId);
    }

    function test_Execute_RevertAlreadyExecuted() public {
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, "");

        vm.prank(owner2);
        wallet.confirm(proposalId);

        vm.prank(owner3);
        wallet.execute(proposalId);

        // Try executing again
        vm.prank(owner3);
        vm.expectRevert(MultiSigWallet.ProposalAlreadyExecuted.selector);
        wallet.execute(proposalId);
    }

    function test_Execute_RevertExecutionFailed() public {
        // Prepare target to revert
        target.setShouldRevert(true);

        bytes memory data = abi.encodeWithSignature("doSomething()");
        
        vm.prank(owner1);
        uint256 proposalId = wallet.propose(address(target), 1 ether, data);

        vm.prank(owner2);
        wallet.confirm(proposalId);

        vm.prank(owner3);
        vm.expectRevert(MultiSigWallet.ExecutionFailed.selector);
        wallet.execute(proposalId);
    }

    function test_Receive_ETH() public {
        uint256 initialBalance = address(wallet).balance;
        (bool success, ) = address(wallet).call{value: 2 ether}("");
        assertTrue(success);
        assertEq(address(wallet).balance, initialBalance + 2 ether);
    }
}
