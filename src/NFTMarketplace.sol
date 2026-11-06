// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is Ownable, ReentrancyGuard {
    // Variables
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listing; // nested mapping

    // Events
    event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
    event NFTSold(address buyer, address seller, address nftContract, uint256 tokenId, uint256 price);

    constructor() Ownable(msg.sender) {}

    // List NFTs
    function listNFT(address nftContract_, uint256 tokenId_, uint256 price_) external nonReentrant {
        require(price_ > 0, "Price can not be 0");
        address owner_ = IERC721(nftContract_).ownerOf(tokenId_);
        require(owner_ == msg.sender, "You are not the owner of the NFT");

        Listing memory listing_ =
            Listing({seller: msg.sender, nftContract: nftContract_, tokenId: tokenId_, price: price_});

        listing[nftContract_][tokenId_] = listing_;

        emit NFTListed(msg.sender, nftContract_, tokenId_, price_);
    }

    // Buy NFTs
    function buyNFT(address nftContract_, uint256 tokenId_) external payable nonReentrant {
        // CEI PATTERN
        // CHECKS
        Listing memory listing_ = listing[nftContract_][tokenId_];
        // 1. Verify NFT is listed on marketplace
        require(listing_.price > 0, "Listing not exists");
        // 2. Verify price paid buyer is equal to seller's price NFT
        require(msg.value == listing_.price, "Incorrect price");

        // EFFECTS:
        // 1. Remove NFT from marketplace
        delete listing[nftContract_][tokenId_];
        // 2. Transfer NFT from seller to buyer
        IERC721(nftContract_).safeTransferFrom(listing_.seller, msg.sender, listing_.tokenId);
        // 3. Transfer ETH from seller to buyer
        (bool success,) = listing_.seller.call{value: msg.value}("");
        require(success, "Transfer failed");

        // INTERACTIONS:
        // Trigger sale event
        emit NFTSold(msg.sender, listing_.seller, listing_.nftContract, listing_.tokenId, listing_.price);
    }

    // Cancel List
    function cancelList(address nftContract_, uint256 tokenId_) external nonReentrant {
        Listing memory listing_ = listing[nftContract_][tokenId_];
        require(listing_.seller == msg.sender, "You are not the listing owner");

        delete listing[nftContract_][tokenId_];

        emit NFTCancelled(msg.sender, nftContract_, tokenId_);
    }
}
