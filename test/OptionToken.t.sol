// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OptionToken} from "../src/OptionToken.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionTokenTest is Test {
    OptionToken public optionToken;
    MockUSDT public usdt;

    address public owner = address(0x1);
    address public user = address(0x2);

    uint256 public strikePrice = 3000 * 10**6; // 3000 USDT per ETH
    uint256 public expiry;

    receive() external payable {}

    function setUp() public {
        expiry = block.timestamp + 7 days;
        usdt = new MockUSDT();
        
        vm.prank(owner);
        optionToken = new OptionToken(strikePrice, expiry, address(usdt));

        // Deal some ETH to owner and user
        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);

        // Mint USDT to user
        usdt.mint(user, 100_000 * 10**6);
    }

    // 1. Creation tests
    function testConstructorParameters() public view {
        assertEq(optionToken.strikePrice(), strikePrice);
        assertEq(optionToken.expiry(), expiry);
        assertEq(address(optionToken.usdt()), address(usdt));
        assertEq(optionToken.owner(), owner);
    }

    function testConstructorInvalidParams() public {
        vm.expectRevert("Strike price must be greater than 0");
        new OptionToken(0, expiry, address(usdt));

        vm.expectRevert("Expiry must be in the future");
        new OptionToken(strikePrice, block.timestamp - 1, address(usdt));

        vm.expectRevert("Invalid USDT address");
        new OptionToken(strikePrice, expiry, address(0));
    }

    // 2. Mint tests (Owner only)
    function testMintSuccessful() public {
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();

        assertEq(optionToken.balanceOf(owner), 10 ether);
        assertEq(address(optionToken).balance, 10 ether);
    }

    function testMintFailNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        optionToken.mint{value: 10 ether}();
    }

    function testMintFailAfterExpiry() public {
        // Warp time to after expiry
        vm.warp(expiry + 1);
        vm.prank(owner);
        vm.expectRevert("Cannot mint after expiry");
        optionToken.mint{value: 10 ether}();
    }

    // 3. Exercise tests
    function testExerciseSuccessful() public {
        // First, owner mints option tokens and transfers some to user
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();

        vm.prank(owner);
        optionToken.transfer(user, 5 ether);

        // Pre-exercise checks
        assertEq(optionToken.balanceOf(user), 5 ether);
        assertEq(address(optionToken).balance, 10 ether);

        // Warp to expiry day
        vm.warp(expiry);

        // Approve USDT for option token contract
        // Option amount to exercise: 2 ETH (2 ether OptionToken)
        // USDT cost: 2 * 3000 = 6000 USDT = 6000 * 10^6
        uint256 exerciseAmount = 2 ether;
        uint256 expectedUSDT = (exerciseAmount * strikePrice) / 1e18; // 6000 * 10^6
        assertEq(expectedUSDT, 6000 * 10**6);

        vm.prank(user);
        usdt.approve(address(optionToken), expectedUSDT);

        uint256 userEthBefore = user.balance;
        uint256 userUsdtBefore = usdt.balanceOf(user);
        uint256 contractEthBefore = address(optionToken).balance;
        uint256 contractUsdtBefore = usdt.balanceOf(address(optionToken));

        vm.prank(user);
        optionToken.exercise(exerciseAmount);

        // Post-exercise checks
        assertEq(optionToken.balanceOf(user), 3 ether); // 5 - 2
        assertEq(user.balance, userEthBefore + exerciseAmount);
        assertEq(usdt.balanceOf(user), userUsdtBefore - expectedUSDT);
        assertEq(address(optionToken).balance, contractEthBefore - exerciseAmount);
        assertEq(usdt.balanceOf(address(optionToken)), contractUsdtBefore + expectedUSDT);
    }

    function testExerciseFailBeforeExpiry() public {
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();
        vm.prank(owner);
        optionToken.transfer(user, 5 ether);

        vm.warp(expiry - 1);
        
        vm.prank(user);
        usdt.approve(address(optionToken), 10000 * 10**6);

        vm.prank(user);
        vm.expectRevert("Exercise window has not opened yet");
        optionToken.exercise(1 ether);
    }

    function testExerciseFailAfterWindow() public {
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();
        vm.prank(owner);
        optionToken.transfer(user, 5 ether);

        // Expiry window is 24 hours (86400 seconds)
        vm.warp(expiry + 24 hours);

        vm.prank(user);
        usdt.approve(address(optionToken), 10000 * 10**6);

        vm.prank(user);
        vm.expectRevert("Exercise window has closed");
        optionToken.exercise(1 ether);
    }

    function testExerciseFailInsufficientBalance() public {
        vm.warp(expiry);
        vm.prank(user);
        vm.expectRevert("Insufficient option token balance");
        optionToken.exercise(1 ether);
    }

    // 4. Expiry burn/redemption tests (Owner only)
    function testBurnExpiredSuccessful() public {
        // Owner mints 10 ETH options
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();

        // 4 ETH is transferred to user, 6 ETH is kept by owner
        vm.prank(owner);
        optionToken.transfer(user, 4 ether);

        // User exercises 2 ETH options
        vm.warp(expiry);
        vm.prank(user);
        usdt.approve(address(optionToken), 6000 * 10**6);
        vm.prank(user);
        optionToken.exercise(2 ether);

        // Now, contract has:
        // ETH: 10 - 2 = 8 ETH
        // USDT: 6000 USDT (from user exercise)
        // OptionToken Supply: 8 OptionToken (6 held by owner, 2 held by user)
        assertEq(address(optionToken).balance, 8 ether);
        assertEq(usdt.balanceOf(address(optionToken)), 6000 * 10**6);

        // Warp after exercise window closes
        vm.warp(expiry + 24 hours);

        // Clean expired token of user (anyone can call it)
        optionToken.cleanExpiredToken(user);
        assertEq(optionToken.balanceOf(user), 0);

        // Owner calls burnExpired
        uint256 ownerEthBefore = owner.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);

        vm.prank(owner);
        optionToken.burnExpired();

        // All 8 ETH and 6000 USDT should be returned to owner
        assertEq(address(optionToken).balance, 0);
        assertEq(usdt.balanceOf(address(optionToken)), 0);
        assertEq(owner.balance, ownerEthBefore + 8 ether);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + 6000 * 10**6);

        // Owner's 6 option tokens should be burned
        assertEq(optionToken.balanceOf(owner), 0);
        assertEq(optionToken.totalSupply(), 0);
    }

    function testBurnExpiredFailBeforeWindowCloses() public {
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();

        vm.warp(expiry + 24 hours - 1);
        
        vm.prank(owner);
        vm.expectRevert("Exercise window is still open");
        optionToken.burnExpired();
    }

    function testBurnExpiredFailNonOwner() public {
        vm.warp(expiry + 24 hours);
        
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        optionToken.burnExpired();
    }

    function testCleanExpiredTokenFailBeforeWindowCloses() public {
        vm.prank(owner);
        optionToken.mint{value: 10 ether}();
        
        vm.warp(expiry + 24 hours - 1);
        
        vm.expectRevert("Exercise window is still open");
        optionToken.cleanExpiredToken(owner);
    }
}
