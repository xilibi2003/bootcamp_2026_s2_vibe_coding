// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BootCampS2} from "../src/BootCampS2.sol";
import {MyToken} from "../src/MyToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    MyToken internal token;
    BootCampS2 internal nft;
    NFTMarket internal market;

    address internal seller = address(0xA11CE);
    address internal buyer = address(0xB0B);

    uint256 internal tokenId;
    uint256 internal price = 100 ether;

    function setUp() public {
        token = new MyToken("ETT");
        nft = new BootCampS2();
        market = new NFTMarket(address(token), address(nft));

        tokenId = nft.mint(seller, "ipfs://example/1.json");
        assertTrue(token.transfer(buyer, 1_000 ether));
    }

    function testListTransfersNftToMarket() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);

        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertEq(nft.ownerOf(tokenId), address(market));
    }

    function testBuyNFTTransfersTokenAndNft() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        vm.prank(buyer);
        market.buyNFT(tokenId, price);

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);

        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    function testTransferAndCallBuysNFT() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        vm.prank(buyer);
        assertTrue(
            token.transferAndCall(address(market), price, abi.encode(tokenId))
        );

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);

        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
        assertEq(token.balanceOf(address(market)), 0);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    function testBuyNFTRequiresExactAmount() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        vm.expectRevert(NFTMarket.NFTMarket_IncorrectAmount.selector);
        vm.prank(buyer);
        market.buyNFT(tokenId, price - 1);
    }

    function testTransferAndCallRequiresExactAmount() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.expectRevert(NFTMarket.NFTMarket_IncorrectAmount.selector);
        vm.prank(buyer);
        token.transferAndCall(address(market), price - 1, abi.encode(tokenId));
    }

    function testListRequiresOwner() public {
        vm.expectRevert();
        vm.prank(buyer);
        market.list(tokenId, price);
    }
}
