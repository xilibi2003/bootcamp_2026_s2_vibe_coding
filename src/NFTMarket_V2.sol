// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NFTMarket} from "./NFTMarket.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @custom:oz-upgrades-from NFTMarket
contract NFTMarket_V2 is NFTMarket, EIP712Upgradeable {
    bytes32 public constant PERMIT_LIST_TYPEHASH =
        keccak256("PermitList(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) public nonces;

    error NFTMarket_SignatureExpired();
    error NFTMarket_InvalidSignature();

    /// @custom:oz-upgrades-validate-as-initializer
    function initializeV2() public reinitializer(2) {
        __EIP712_init("NFTMarket", "2");
    }

    function permitList(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert NFTMarket_SignatureExpired();
        if (price == 0) revert NFTMarket_PriceIsZero();
        if (price > type(uint96).max) revert NFTMarket_PriceTooHigh();

        address seller = nft.ownerOf(tokenId);
        uint256 nonce = nonces[seller];

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_LIST_TYPEHASH,
                tokenId,
                price,
                nonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        if (signer != seller) revert NFTMarket_InvalidSignature();

        nonces[seller]++;

        // Transfer the NFT using setApprovalForAll approval
        nft.safeTransferFrom(seller, address(this), tokenId);

        // Record listing
        listings[tokenId] = Listing({seller: seller, price: uint96(price)});

        emit Listed(seller, tokenId, price);
    }
}
