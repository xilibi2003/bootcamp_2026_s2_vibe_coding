// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BootCampS2} from "../src/BootCampS2.sol";
import {MyToken} from "../src/MyToken.sol";
import {NFTMarket2} from "../src/NFTMarket2.sol";

contract NFTMarket2Test is Test {
    MyToken internal token;
    BootCampS2 internal nft;
    NFTMarket2 internal market;

    address internal seller = address(0xA11CE);
    address internal buyer = address(0xB0B);

    uint256 internal signerPrivateKey = 0x1337;
    address internal whitelistSigner;

    uint256 internal tokenId;
    uint256 internal price = 100 ether;

    function setUp() public {
        whitelistSigner = vm.addr(signerPrivateKey);

        token = new MyToken("ETT");
        nft = new BootCampS2();
        market = new NFTMarket2(address(token), address(nft), whitelistSigner);

        tokenId = nft.mint(seller, "ipfs://example/1.json");
        assertTrue(token.transfer(buyer, 1_000 ether));
    }

    function getPermitBuySignature(
        address buyerAddr,
        uint256 tokenIdVal,
        uint256 deadlineVal,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                market.PERMIT_BUY_TYPEHASH(),
                buyerAddr,
                tokenIdVal,
                deadlineVal
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                market.domainSeparator(),
                structHash
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
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

    function testWhitelistPermitBuySuccess() public {
        // 1. Seller lists NFT
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        // 2. Buyer approves market to spend ETT
        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        // 3. Generate whitelist permitBuy signature for buyer from project backend signer
        uint256 deadline = block.timestamp + 3600;
        bytes memory signature = getPermitBuySignature(
            buyer,
            tokenId,
            deadline,
            signerPrivateKey
        );

        // 4. Buyer executes permitBuy
        uint256 sellerBalanceBefore = token.balanceOf(seller);

        vm.prank(buyer);
        market.permitBuy(tokenId, price, deadline, signature);

        // Verify NFT and token transfers occurred correctly
        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    function testWhitelistPermitBuyRevertsIfSignatureExpired() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        // Generate expired signature
        uint256 deadline = block.timestamp - 1;
        bytes memory signature = getPermitBuySignature(
            buyer,
            tokenId,
            deadline,
            signerPrivateKey
        );

        vm.expectRevert("NFTMarket2: signature expired");
        vm.prank(buyer);
        market.permitBuy(tokenId, price, deadline, signature);
    }

    function testWhitelistPermitBuyRevertsIfSignedByNonWhitelist() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        // Signed by non-whitelist signer (private key 0x9999)
        uint256 deadline = block.timestamp + 3600;
        bytes memory signature = getPermitBuySignature(
            buyer,
            tokenId,
            deadline,
            0x9999
        );

        vm.expectRevert("NFTMarket2: invalid whitelist signature");
        vm.prank(buyer);
        market.permitBuy(tokenId, price, deadline, signature);
    }

    function testWhitelistPermitBuyRevertsIfWrongBuyerSignature() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        assertTrue(token.approve(address(market), price));

        // Signed for a different address (address(0xDEAD)) instead of buyer
        uint256 deadline = block.timestamp + 3600;
        bytes memory signature = getPermitBuySignature(
            address(0xDEAD),
            tokenId,
            deadline,
            signerPrivateKey
        );

        vm.expectRevert("NFTMarket2: invalid whitelist signature");
        vm.prank(buyer);
        market.permitBuy(tokenId, price, deadline, signature);
    }

    function testWhitelistTransferAndCallPermitBuy() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        vm.prank(seller);
        market.list(tokenId, price);

        uint256 deadline = block.timestamp + 3600;
        bytes memory signature = getPermitBuySignature(
            buyer,
            tokenId,
            deadline,
            signerPrivateKey
        );

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // Encode payload for transferAndCall: (tokenId, deadline, signature)
        bytes memory data = abi.encode(tokenId, deadline, signature);

        vm.prank(buyer);
        assertTrue(
            token.transferAndCall(address(market), price, data)
        );

        // Verify NFT and token transfers occurred correctly
        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
        assertEq(token.balanceOf(seller), sellerBalanceBefore + price);
        assertEq(nft.ownerOf(tokenId), buyer);
    }
}
