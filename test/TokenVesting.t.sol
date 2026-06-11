// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {
        _mint(msg.sender, 2_000_000 * 10**18);
    }
}

contract TokenVestingTest is Test {
    MockToken internal token;
    TokenVesting internal vesting;

    address internal beneficiary = address(0x999);
    uint256 internal deployTime;
    uint256 public constant MONTH = 30 days;
    uint256 public constant TOTAL_ALLOCATION = 1_000_000 * 10**18;

    function setUp() public {
        token = new MockToken();
        deployTime = block.timestamp;

        vesting = new TokenVesting(beneficiary, address(token));

        // Vesting 合约部署后，并转入 100 万 ERC20 资产
        token.transfer(address(vesting), TOTAL_ALLOCATION);
    }

    function testInitialState() public view {
        assertEq(vesting.owner(), beneficiary);
        assertEq(address(vesting.vestingToken()), address(token));
        assertEq(token.balanceOf(address(vesting)), TOTAL_ALLOCATION);
        assertEq(vesting.start(), deployTime + 12 * MONTH);
        assertEq(vesting.duration(), 24 * MONTH);
        assertEq(vesting.end(), deployTime + 36 * MONTH);
    }

    function testNoReleaseBeforeCliff() public {
        // Warp to Month 6
        vm.warp(deployTime + 6 * MONTH);
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 0);
        assertEq(vesting.releasable(address(token)), 0);

        // Attempt release
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 0);
    }

    function testNoReleaseAtCliffEnd() public {
        // Warp to Month 12 (exact cliff time)
        vm.warp(deployTime + 12 * MONTH);
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 0);
        assertEq(vesting.releasable(address(token)), 0);

        // Attempt release
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 0);
    }

    function testNoReleaseJustBeforeMonth13() public {
        // Warp to 12 months + 29 days (just before 13th month release)
        vm.warp(deployTime + 12 * MONTH + 29 days);
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 0);
        assertEq(vesting.releasable(address(token)), 0);
    }

    function testFirstReleaseAtMonth13() public {
        // Warp to Month 13 (cliff + 1 month)
        vm.warp(deployTime + 13 * MONTH);

        uint256 expectedVested = TOTAL_ALLOCATION / 24;
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), expectedVested);
        assertEq(vesting.releasable(address(token)), expectedVested);

        // Release to beneficiary
        vesting.release();
        assertEq(token.balanceOf(beneficiary), expectedVested);
        assertEq(vesting.releasable(address(token)), 0);
    }

    function testVestingStaysConstantDuringMonth() public {
        // Warp to Month 13 (cliff + 1 month)
        vm.warp(deployTime + 13 * MONTH);
        uint256 vestedAt13 = vesting.vestedAmount(address(token), uint64(block.timestamp));

        // Warp to Month 13 + 15 days (midway through Month 13)
        vm.warp(deployTime + 13 * MONTH + 15 days);
        uint256 vestedAt13_5 = vesting.vestedAmount(address(token), uint64(block.timestamp));

        // Vested amount should be identical due to monthly discrete steps
        assertEq(vestedAt13_5, vestedAt13);
    }

    function testVestingMidwayAtMonth24() public {
        // Warp to Month 24 (cliff + 12 months)
        vm.warp(deployTime + 24 * MONTH);

        uint256 expectedVested = (TOTAL_ALLOCATION * 12) / 24; // 50%
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), expectedVested);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), expectedVested);
    }

    function testFullVestingAtMonth36() public {
        // Warp to Month 36 (cliff + 24 months)
        vm.warp(deployTime + 36 * MONTH);

        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), TOTAL_ALLOCATION);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function testVestingAfterMonth36() public {
        // Warp to Month 40
        vm.warp(deployTime + 40 * MONTH);

        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), TOTAL_ALLOCATION);

        vesting.release();
        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
    }
}
