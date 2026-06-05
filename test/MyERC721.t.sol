// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {NMTNFT} from "../src/MyERC721.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

// V2 implementation for testing upgrades
contract NMTNFTV2 is NMTNFT {
    function version() external pure returns (string memory) {
        return "v2";
    }
}

contract MyERC721Test is Test {
    NMTNFT internal proxy;

    address internal owner = address(0x1);
    address internal alice = address(0x2);
    address internal bob = address(0x3);

    function setUp() public {
        bytes memory initData = abi.encodeWithSelector(
            NMTNFT.initialize.selector,
            owner
        );
        address proxyAddr = Upgrades.deployUUPSProxy(
            "MyERC721.sol:NMTNFT",
            initData
        );
        proxy = NMTNFT(proxyAddr);
    }

    function testNameAndSymbol() public view {
        assertEq(proxy.name(), "NMTNFT");
        assertEq(proxy.symbol(), "NMT");
    }

    function testOwner() public view {
        assertEq(proxy.owner(), owner);
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert(); // Initializable error
        proxy.initialize(alice);
    }

    function testMint() public {
        vm.prank(owner);
        uint256 tokenId = proxy.mint(alice, "ipfs://test");

        assertEq(tokenId, 1);
        assertEq(proxy.ownerOf(tokenId), alice);
        assertEq(proxy.tokenURI(tokenId), "ipfs://test");
    }

    function testOnlyOwnerCanMint() public {
        vm.prank(alice);
        vm.expectRevert();
        proxy.mint(bob, "ipfs://test");
    }

    function testUpgrade() public {
        Options memory opts;
        opts.referenceContract = "MyERC721.sol:NMTNFT";

        // Perform upgrade by owner
        Upgrades.upgradeProxy(
            address(proxy),
            "MyERC721.t.sol:NMTNFTV2",
            "",
            opts,
            owner
        );

        // Verify the upgrade succeeded and we can call the new function
        NMTNFTV2 proxyV2 = NMTNFTV2(address(proxy));
        assertEq(proxyV2.version(), "v2");

        // Verify existing functionalities still work
        vm.prank(owner);
        uint256 tokenId = proxyV2.mint(alice, "ipfs://after-upgrade");
        assertEq(proxyV2.tokenURI(tokenId), "ipfs://after-upgrade");
    }

    function testCannotUpgradeIfNotOwner() public {
        // Deploy a new implementation contract to attempt upgrading to
        NMTNFTV2 newImplementation = new NMTNFTV2();

        // Attempt upgrade as non-owner (alice) directly on the proxy, which should revert
        vm.prank(alice);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImplementation), "");
    }
}
