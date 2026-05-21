// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {BootCampS2} from "./BootCampS2.sol";
import {MyToken} from "./MyToken.sol";

contract NFTMarket is IERC721Receiver {
    using SafeERC20 for IERC20;

    MyToken public immutable token;
    BootCampS2 public immutable nft;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 tokenId => Listing) public listings;

    event Listed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event Sold(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

    constructor(address tokenAddress, address nftAddress) {
        require(tokenAddress != address(0), "NFTMarket: token is zero address");
        require(nftAddress != address(0), "NFTMarket: nft is zero address");

        token = MyToken(tokenAddress);
        nft = BootCampS2(nftAddress);
    }

    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "NFTMarket: price is zero");
        require(nft.ownerOf(tokenId) == msg.sender, "NFTMarket: caller is not owner");

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing memory listing = listings[tokenId];

        require(listing.seller != address(0), "NFTMarket: nft is not listed");
        require(amount == listing.price, "NFTMarket: incorrect amount");

        delete listings[tokenId];

        IERC20(address(token)).safeTransferFrom(
            msg.sender,
            listing.seller,
            amount
        );
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Sold(msg.sender, listing.seller, tokenId, amount);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
