// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DAOToken} from "../src/DAOToken.sol";
import {DAOGov} from "../src/DAOGov.sol";
import {Bank} from "../src/Bank.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";

contract DAOGovTest is Test {
    DAOToken public token;
    DAOGov public gov;
    Bank public bank;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public depositor = address(0x3);

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant ALICE_TOKENS = 100_000 * 10**18;
    uint256 public constant DEPOSIT_AMOUNT = 5 ether;

    function setUp() public {
        // 1. Deploy DAOToken as owner
        vm.prank(owner);
        token = new DAOToken("DAO Token", "DAO", INITIAL_SUPPLY);

        // 2. Deploy DAOGov governed by DAOToken
        gov = new DAOGov(token);

        // 3. Deploy Bank
        bank = new Bank();

        // 4. Setup voting power: Transfer tokens to Alice and delegate to activate checkpoints
        vm.prank(owner);
        assertTrue(token.transfer(alice, ALICE_TOKENS));

        vm.prank(alice);
        token.delegate(alice);

        // 5. Deposit funds to Bank
        vm.deal(depositor, DEPOSIT_AMOUNT);
        vm.prank(depositor);
        bank.deposit{value: DEPOSIT_AMOUNT}();

        // Ensure Bank has the deposit
        assertEq(address(bank).balance, DEPOSIT_AMOUNT);
    }

    function testGovernorCanWithdrawFromBank() public {
        // 1. Transfer Bank Admin to Governor contract
        bank.transferAdmin(address(gov));
        assertEq(bank.admin(), address(gov));

        // 2. Setup Proposal parameters for calling Bank.withdraw()
        address[] memory targets = new address[](1);
        targets[0] = address(bank);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("withdraw()");

        string memory description = "Proposal: Withdraw all funds from Bank to DAOGov";

        // 3. Propose as Alice
        vm.prank(alice);
        uint256 proposalId = gov.propose(targets, values, calldatas, description);

        // Assert proposal is initially Pending
        assertEq(uint8(gov.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // 4. Warp/Roll past voting delay (1 block delay)
        vm.roll(block.number + gov.votingDelay() + 1);
        assertEq(uint8(gov.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // 5. Cast vote: Alice votes For (support = 1)
        vm.prank(alice);
        gov.castVote(proposalId, 1); // 1 = For

        // 6. Warp/Roll past voting period (10 blocks voting duration)
        vm.roll(block.number + gov.votingPeriod() + 1);
        assertEq(uint8(gov.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // 7. Verify balances before execution
        uint256 bankBalanceBefore = address(bank).balance;
        uint256 govBalanceBefore = address(gov).balance;
        assertEq(bankBalanceBefore, DEPOSIT_AMOUNT);
        assertEq(govBalanceBefore, 0);

        // 8. Execute the proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        gov.execute(targets, values, calldatas, descriptionHash);

        // 9. Verify outcomes
        assertEq(uint8(gov.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertEq(address(bank).balance, 0);
        assertEq(address(gov).balance, DEPOSIT_AMOUNT);
    }
}
