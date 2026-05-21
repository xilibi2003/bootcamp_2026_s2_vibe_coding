// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BootCampS2} from "../src/BootCampS2.sol";

contract BootCampS2Test is Test {
    BootCampS2 internal nft;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        nft = new BootCampS2();
    }

    function testMintSetsTokenUri() public {
        uint256 tokenId = nft.mint(alice, "ipfs://example/1.json");

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), "ipfs://example/1.json");
    }

    function testOnlyOwnerCanMint() public {
        vm.prank(bob);
        vm.expectRevert();
        nft.mint(bob, "ipfs://example/2.json");
    }
}
