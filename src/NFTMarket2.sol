// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IERC1363Receiver
} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";
import {
    IERC721Receiver
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {
    EIP712
} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {BootCampS2} from "./BootCampS2.sol";
import {MyToken} from "./MyToken.sol";

contract NFTMarket2 is IERC721Receiver, IERC1363Receiver, EIP712 {
    using SafeERC20 for IERC20;

    MyToken public immutable token;
    BootCampS2 public immutable nft;
    address public immutable whitelistSigner;

    bytes32 public constant PERMIT_BUY_TYPEHASH =
        keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 deadline)");

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

    constructor(
        address tokenAddress,
        address nftAddress,
        address _whitelistSigner
    ) EIP712("NFTMarket2", "1") {
        require(tokenAddress != address(0), "NFTMarket: token is zero address");
        require(nftAddress != address(0), "NFTMarket: nft is zero address");
        require(
            _whitelistSigner != address(0),
            "NFTMarket: signer is zero address"
        );

        token = MyToken(tokenAddress);
        nft = BootCampS2(nftAddress);
        whitelistSigner = _whitelistSigner;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "NFTMarket: price is zero");
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "NFTMarket: caller is not owner"
        );

        listings[tokenId] = Listing({seller: msg.sender, price: price});

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Listed(msg.sender, tokenId, price);
    }

    // Direct purchase using signature verification
    function permitBuy(
        uint256 tokenId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "NFTMarket2: signature expired");

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_BUY_TYPEHASH, msg.sender, tokenId, deadline)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(
            signer == whitelistSigner,
            "NFTMarket2: invalid whitelist signature"
        );

        _buyNFT(tokenId, amount, msg.sender, false);
    }

    // Direct purchase via transferAndCall (ERC1363)
    function onTransferReceived(
        address,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(msg.sender == address(token), "NFTMarket: unsupported token");

        (uint256 tokenId, uint256 deadline, bytes memory signature) = abi
            .decode(data, (uint256, uint256, bytes));

        require(block.timestamp <= deadline, "NFTMarket2: signature expired");

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_BUY_TYPEHASH, from, tokenId, deadline)
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(
            signer == whitelistSigner,
            "NFTMarket2: invalid whitelist signature"
        );

        _buyNFT(tokenId, value, from, true);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _buyNFT(
        uint256 tokenId,
        uint256 amount,
        address buyer,
        bool tokenAlreadyReceived
    ) internal {
        Listing memory listing = listings[tokenId];

        require(listing.seller != address(0), "NFTMarket: nft is not listed");
        require(amount == listing.price, "NFTMarket: incorrect amount");

        delete listings[tokenId];

        if (tokenAlreadyReceived) {
            IERC20(address(token)).safeTransfer(listing.seller, amount);
        } else {
            IERC20(address(token)).safeTransferFrom(
                buyer,
                listing.seller,
                amount
            );
        }

        nft.safeTransferFrom(address(this), buyer, tokenId);

        emit Sold(buyer, listing.seller, tokenId, amount);
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
