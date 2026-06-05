// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {NFTMarket} from "./NFTMarket.sol";
import {MyPermitToken} from "./MyPermitToken.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {BootCampS2} from "./BootCampS2.sol";
import {MyToken} from "./MyToken.sol";

contract AirdopMerkleNFTMarket is Multicall, NFTMarket {
    bytes32 public immutable merkleRoot;
    mapping(address => bool) public hasClaimed;

    error AirdopMerkleNFTMarket_AlreadyClaimed();
    error AirdopMerkleNFTMarket_NotInWhitelist();

    constructor(
        address tokenAddress,
        address nftAddress,
        bytes32 _merkleRoot
    ) {
        token = MyToken(tokenAddress);
        nft = BootCampS2(nftAddress);
        merkleRoot = _merkleRoot;
    }

    // Overrides to resolve conflict between Context and ContextUpgradeable
    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(Context, ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ContextUpgradeable) returns (uint256) {
        return super._contextSuffixLength();
    }

    // permitPrePay with spender argument
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        MyPermitToken(address(token)).permit(owner, spender, value, deadline, v, r, s);
    }

    // permitPrePay without spender argument (defaults spender to address(this))
    function permitPrePay(
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        MyPermitToken(address(token)).permit(owner, address(this), value, deadline, v, r, s);
    }

    // claimNFT with proof second
    function claimNFT(uint256 tokenId, bytes32[] calldata proof) external {
        _claimNFT(tokenId, proof);
    }

    // claimNFT with proof first
    function claimNFT(bytes32[] calldata proof, uint256 tokenId) external {
        _claimNFT(tokenId, proof);
    }

    function _claimNFT(uint256 tokenId, bytes32[] calldata proof) internal {
        if (hasClaimed[msg.sender]) {
            revert AirdopMerkleNFTMarket_AlreadyClaimed();
        }

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert AirdopMerkleNFTMarket_NotInWhitelist();
        }

        Listing storage listing = listings[tokenId];
        address seller = listing.seller;
        uint256 price = listing.price;

        if (seller == address(0)) revert NFTMarket_NftIsNotListed();

        uint256 claimPrice = price / 2;

        hasClaimed[msg.sender] = true;
        delete listings[tokenId];

        // Transfer token from buyer (msg.sender) to seller
        token.transferFrom(msg.sender, seller, claimPrice);

        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Sold(msg.sender, seller, tokenId, claimPrice);
    }
}
