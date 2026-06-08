// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BootCampS2} from "../src/BootCampS2.sol";
import {MyToken} from "../src/MyToken.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {NFTMarket_V2} from "../src/NFTMarket_V2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract NFTMarketV2Test is Test {
    MyToken internal token;
    BootCampS2 internal nft;
    NFTMarket_V2 internal market;

    uint256 internal sellerPrivateKey = 0xA11CE;
    address internal seller;
    address internal buyer = address(0xB0B);

    uint256 internal tokenId;
    uint256 internal price = 100 ether;

    function setUp() public {
        seller = vm.addr(sellerPrivateKey);

        token = new MyToken("ETT");
        nft = new BootCampS2();

        // 1. Deploy NFTMarket V1 Proxy
        address marketProxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            abi.encodeWithSelector(
                NFTMarket.initialize.selector,
                address(token),
                address(nft),
                address(this) // owner
            )
        );

        // 2. Upgrade to NFTMarket V2
        Options memory opts;
        opts.unsafeAllow = "missing-initializer-call,incorrect-initializer-order";
        Upgrades.upgradeProxy(
            marketProxy,
            "NFTMarket_V2.sol:NFTMarket_V2",
            abi.encodeCall(NFTMarket_V2.initializeV2, ()),
            opts
        );

        market = NFTMarket_V2(marketProxy);

        // Mint NFT to seller
        tokenId = nft.mint(seller, "ipfs://example/1.json");
    }

    function testUpgradeProperties() public view {
        assertEq(address(market.token()), address(token));
        assertEq(address(market.nft()), address(nft));
    }

    function testPermitList() public {
        // Seller approves NFT Market
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        uint256 nonce = market.nonces(seller);
        uint256 deadline = block.timestamp + 1 hours;

        // Construct EIP-712 digest
        bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeparator = keccak256(abi.encode(
            typeHash,
            keccak256(bytes("NFTMarket")),
            keccak256(bytes("2")),
            block.chainid,
            address(market)
        ));

        bytes32 structHash = keccak256(abi.encode(
            market.PERMIT_LIST_TYPEHASH(),
            tokenId,
            price,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Anyone can call permitList to list the NFT on behalf of the seller
        vm.prank(buyer);
        market.permitList(tokenId, price, deadline, signature);

        // Verify listing details
        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);

        // Verify NFT ownership transferred to market
        assertEq(nft.ownerOf(tokenId), address(market));

        // Verify nonce incremented
        assertEq(market.nonces(seller), nonce + 1);
    }

    function testPermitListFailsExpiredSignature() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        uint256 nonce = market.nonces(seller);
        uint256 deadline = block.timestamp - 1; // Expired

        bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeparator = keccak256(abi.encode(
            typeHash,
            keccak256(bytes("NFTMarket")),
            keccak256(bytes("2")),
            block.chainid,
            address(market)
        ));

        bytes32 structHash = keccak256(abi.encode(
            market.PERMIT_LIST_TYPEHASH(),
            tokenId,
            price,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(NFTMarket_V2.NFTMarket_SignatureExpired.selector);
        market.permitList(tokenId, price, deadline, signature);
    }

    function testPermitListFailsInvalidSignature() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        uint256 nonce = market.nonces(seller);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeparator = keccak256(abi.encode(
            typeHash,
            keccak256(bytes("NFTMarket")),
            keccak256(bytes("2")),
            block.chainid,
            address(market)
        ));

        bytes32 structHash = keccak256(abi.encode(
            market.PERMIT_LIST_TYPEHASH(),
            tokenId,
            price,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));

        // Sign with a different private key (buyer instead of seller)
        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(NFTMarket_V2.NFTMarket_InvalidSignature.selector);
        market.permitList(tokenId, price, deadline, signature);
    }
}
