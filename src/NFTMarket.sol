// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    IERC1363Receiver
} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {
    IERC721Receiver
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {BootCampS2} from "./BootCampS2.sol";
import {MyToken} from "./MyToken.sol";

contract NFTMarket is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC721Receiver, IERC1363Receiver {
    MyToken public token;
    BootCampS2 public nft;

    struct Listing {
        address seller; // 160 bits
        uint96 price; // 96 bits (packed in the same 32-byte slot)
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

    error NFTMarket_TokenIsZeroAddress();
    error NFTMarket_NftIsZeroAddress();
    error NFTMarket_PriceIsZero();
    error NFTMarket_PriceTooHigh();
    error NFTMarket_UnsupportedToken();
    error NFTMarket_NftIsNotListed();
    error NFTMarket_IncorrectAmount();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address tokenAddress, address nftAddress, address initialOwner) public initializer {
        if (tokenAddress == address(0)) revert NFTMarket_TokenIsZeroAddress();
        if (nftAddress == address(0)) revert NFTMarket_NftIsZeroAddress();

        __Ownable_init(initialOwner);

        token = MyToken(tokenAddress);
        nft = BootCampS2(nftAddress);
    }

    function list(uint256 tokenId, uint256 price) external {
        if (price == 0) revert NFTMarket_PriceIsZero();
        if (price > type(uint96).max) revert NFTMarket_PriceTooHigh();

        // Transfer first to revert early if caller is not owner/approved, saving revert gas
        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({seller: msg.sender, price: uint96(price)});

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256 tokenId, uint256 amount) external {
        _buyNFT(tokenId, amount, msg.sender, false);
    }

    function onTransferReceived(
        address,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        if (msg.sender != address(token)) revert NFTMarket_UnsupportedToken();

        uint256 tokenId = abi.decode(data, (uint256));
        _buyNFT(tokenId, value, from, true);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _buyNFT(
        uint256 tokenId,
        uint256 amount,
        address buyer,
        bool tokenAlreadyReceived
    ) internal {
        Listing storage listing = listings[tokenId];
        address seller = listing.seller;
        uint256 price = listing.price;

        if (seller == address(0)) revert NFTMarket_NftIsNotListed();
        if (amount != price) revert NFTMarket_IncorrectAmount();

        delete listings[tokenId];

        if (tokenAlreadyReceived) {
            token.transfer(seller, amount);
        } else {
            token.transferFrom(buyer, seller, amount);
        }

        nft.safeTransferFrom(address(this), buyer, tokenId);

        emit Sold(buyer, seller, tokenId, amount);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
