// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BootCampS2} from "../src/BootCampS2.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarketTest is Test {
    MyPermitToken internal token;
    BootCampS2 internal nft;
    AirdopMerkleNFTMarket internal market;

    address internal seller = address(0x999);
    uint256 internal tokenId;
    uint256 internal price = 100 ether;

    // 8 Whitelist addresses
    address[8] internal whitelist = [
        address(0x11),
        address(0x22),
        address(0x33),
        address(0x44),
        address(0x55),
        address(0x66),
        address(0x77),
        address(0x88)
    ];

    uint256 internal claimantPrivateKey = 0xc1a1;
    address internal claimant;
    bytes32 internal merkleRoot;

    function setUp() public {
        token = new MyPermitToken();
        nft = new BootCampS2();

        claimant = vm.addr(claimantPrivateKey);
        whitelist[2] = claimant; // claimant is index 2

        // Build Merkle Root
        merkleRoot = getMerkleRoot();

        market = new AirdopMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );

        tokenId = nft.mint(seller, "ipfs://example/1.json");
    }

    function hashCommutative(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function getMerkleRoot() public view returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
        }

        bytes32[] memory p = new bytes32[](4);
        p[0] = hashCommutative(leaves[0], leaves[1]);
        p[1] = hashCommutative(leaves[2], leaves[3]);
        p[2] = hashCommutative(leaves[4], leaves[5]);
        p[3] = hashCommutative(leaves[6], leaves[7]);

        bytes32[] memory g = new bytes32[](2);
        g[0] = hashCommutative(p[0], p[1]);
        g[1] = hashCommutative(p[2], p[3]);

        return hashCommutative(g[0], g[1]);
    }

    function getProof(uint256 index) public view returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelist[i]));
        }

        bytes32[] memory p = new bytes32[](4);
        p[0] = hashCommutative(leaves[0], leaves[1]);
        p[1] = hashCommutative(leaves[2], leaves[3]);
        p[2] = hashCommutative(leaves[4], leaves[5]);
        p[3] = hashCommutative(leaves[6], leaves[7]);

        bytes32[] memory g = new bytes32[](2);
        g[0] = hashCommutative(p[0], p[1]);
        g[1] = hashCommutative(p[2], p[3]);

        bytes32[] memory proof = new bytes32[](3);
        if (index == 0) {
            proof[0] = leaves[1];
            proof[1] = p[1];
            proof[2] = g[1];
        } else if (index == 1) {
            proof[0] = leaves[0];
            proof[1] = p[1];
            proof[2] = g[1];
        } else if (index == 2) {
            proof[0] = leaves[3];
            proof[1] = p[0];
            proof[2] = g[1];
        } else if (index == 3) {
            proof[0] = leaves[2];
            proof[1] = p[0];
            proof[2] = g[1];
        } else if (index == 4) {
            proof[0] = leaves[5];
            proof[1] = p[3];
            proof[2] = g[0];
        } else if (index == 5) {
            proof[0] = leaves[4];
            proof[1] = p[3];
            proof[2] = g[0];
        } else if (index == 6) {
            proof[0] = leaves[7];
            proof[1] = p[2];
            proof[2] = g[0];
        } else if (index == 7) {
            proof[0] = leaves[6];
            proof[1] = p[2];
            proof[2] = g[0];
        }
        return proof;
    }

    function testClaimNFTSucceedsForWhitelist() public {
        // Seller lists the NFT in the market
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        // Pick whitelist index 2 (claimant)
        bytes32[] memory proof = getProof(2);

        // Whitelist user only pays half price (50 ether)
        uint256 claimPrice = price / 2;
        token.transfer(claimant, claimPrice);
        vm.prank(claimant);
        token.approve(address(market), claimPrice);

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        vm.prank(claimant);
        market.claimNFT(tokenId, proof);

        assertEq(nft.ownerOf(tokenId), claimant);
        assertTrue(market.hasClaimed(claimant));
        assertEq(token.balanceOf(seller), sellerBalanceBefore + claimPrice);
    }

    function testClaimNFTSucceedsForWhitelistAltSignature() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        address otherClaimant = whitelist[3];
        bytes32[] memory proof = getProof(3);

        uint256 claimPrice = price / 2;
        token.transfer(otherClaimant, claimPrice);
        vm.prank(otherClaimant);
        token.approve(address(market), claimPrice);

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // Call the signature where proof is first
        vm.prank(otherClaimant);
        market.claimNFT(proof, tokenId);

        assertEq(nft.ownerOf(tokenId), otherClaimant);
        assertTrue(market.hasClaimed(otherClaimant));
        assertEq(token.balanceOf(seller), sellerBalanceBefore + claimPrice);
    }

    function testClaimNFTFailsForNonWhitelist() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        address attacker = address(0xbad);
        bytes32[] memory proof = getProof(2);

        uint256 claimPrice = price / 2;
        token.transfer(attacker, claimPrice);
        vm.prank(attacker);
        token.approve(address(market), claimPrice);

        vm.expectRevert(AirdopMerkleNFTMarket.AirdopMerkleNFTMarket_NotInWhitelist.selector);
        vm.prank(attacker);
        market.claimNFT(tokenId, proof);
    }

    function testClaimNFTFailsOnDoubleClaim() public {
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        address otherClaimant = whitelist[5];
        bytes32[] memory proof = getProof(5);

        uint256 claimPrice = price / 2;
        token.transfer(otherClaimant, claimPrice * 2);
        vm.prank(otherClaimant);
        token.approve(address(market), claimPrice * 2);

        // 1st claim succeeds
        vm.prank(otherClaimant);
        market.claimNFT(tokenId, proof);

        // Mint and list another NFT for a second claim attempt
        uint256 tokenId2 = nft.mint(seller, "ipfs://example/2.json");
        vm.prank(seller);
        nft.approve(address(market), tokenId2);
        vm.prank(seller);
        market.list(tokenId2, price);

        // 2nd claim fails due to double claim mapping check
        vm.expectRevert(AirdopMerkleNFTMarket.AirdopMerkleNFTMarket_AlreadyClaimed.selector);
        vm.prank(otherClaimant);
        market.claimNFT(tokenId2, proof);
    }

    function testPermitPrePayAndBuyNFT() public {
        uint256 alicePrivateKey = 0xa11ce;
        address alice = vm.addr(alicePrivateKey);

        // Transfer tokens to Alice
        token.transfer(alice, 100 ether);

        // Seller lists NFT
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        // Generate Permit signature
        bytes32 permitTypeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(
            permitTypeHash,
            alice,
            address(market),
            price,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Build multicall calls
        bytes[] memory calls = new bytes[](2);

        // permitPrePay with spender explicitly defined
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            alice,
            address(market),
            price,
            deadline,
            v,
            r,
            s
        );

        // buyNFT
        calls[1] = abi.encodeWithSelector(
            market.buyNFT.selector,
            tokenId,
            price
        );

        // Execute Multicall
        vm.prank(alice);
        market.multicall(calls);

        // Verify state
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(token.balanceOf(seller), price);
    }

    function testPermitPrePayWithoutSpenderAndBuyNFT() public {
        uint256 alicePrivateKey = 0xa11ce;
        address alice = vm.addr(alicePrivateKey);

        token.transfer(alice, 100 ether);

        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        bytes32 permitTypeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = token.nonces(alice);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(
            permitTypeHash,
            alice,
            address(market),
            price,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        bytes[] memory calls = new bytes[](2);

        // permitPrePay without spender (defaults to address(this))
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(address,uint256,uint256,uint8,bytes32,bytes32)",
            alice,
            price,
            deadline,
            v,
            r,
            s
        );

        calls[1] = abi.encodeWithSelector(
            market.buyNFT.selector,
            tokenId,
            price
        );

        vm.prank(alice);
        market.multicall(calls);

        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(token.balanceOf(seller), price);
    }

    function testMulticallPermitPrePayAndClaimNFT() public {
        // Seller lists the NFT
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        vm.prank(seller);
        market.list(tokenId, price);

        // Deal claimant MPT2 tokens (only needs price / 2 = 50 ether)
        uint256 claimPrice = price / 2;
        token.transfer(claimant, claimPrice);

        // Generate Permit signature for claimant
        bytes32 permitTypeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = token.nonces(claimant);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(
            permitTypeHash,
            claimant,
            address(market),
            claimPrice,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantPrivateKey, digest);

        // Build multicall calls
        bytes[] memory calls = new bytes[](2);

        // Call 1: permitPrePay (without spender, defaulting to address(this))
        calls[0] = abi.encodeWithSignature(
            "permitPrePay(address,uint256,uint256,uint8,bytes32,bytes32)",
            claimant,
            claimPrice,
            deadline,
            v,
            r,
            s
        );

        // Call 2: claimNFT
        bytes32[] memory proof = getProof(2);
        calls[1] = abi.encodeWithSignature(
            "claimNFT(uint256,bytes32[])",
            tokenId,
            proof
        );

        uint256 sellerBalanceBefore = token.balanceOf(seller);

        // Execute Multicall
        vm.prank(claimant);
        market.multicall(calls);

        // Verify state
        assertEq(nft.ownerOf(tokenId), claimant);
        assertTrue(market.hasClaimed(claimant));
        assertEq(token.balanceOf(seller), sellerBalanceBefore + claimPrice);
    }
}
