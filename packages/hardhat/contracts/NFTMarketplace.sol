// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTMarketplace is IERC721Receiver {
    using Address for address payable;

    // Struct to store the details of an NFT listing
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    IERC721 private _nftContract; // The ERC721 contract
    uint256 private _feePercentage; // The fee percentage charged by the marketplace
    address private _owner; // Owner of the marketplace
    mapping(uint256 => Listing) private _listings; // Mapping to store the listings

    event ListingCreated(address indexed seller, uint256 indexed tokenId, uint256 price);
    event ListingPriceChanged(uint256 indexed tokenId, uint256 newPrice);
    event ListingRemoved(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Sets the address of the ERC721 contract.
     * @param nftContractAddress The address of the ERC721 contract.
     */
    function setNftContract(address nftContractAddress) external onlyOwner {
        _nftContract = IERC721(nftContractAddress);
    }

    /**
     * @dev Sets the marketplace fee percentage.
     * @param feePercentage The fee percentage to be set.
     */
    function setFeePercentage(uint256 feePercentage) external onlyOwner {
        require(feePercentage <= 100, "Invalid fee percentage");
        _feePercentage = feePercentage;
    }

    /**
     * @dev Lists an NFT for sale.
     * @param tokenId The ID of the token to be listed.
     * @param price The listing price for the token.
     */
    function listNFTForSale(uint256 tokenId, uint256 price) external {
        require(!_listings[tokenId].active, "NFT is already listed");
        require(_nftContract.ownerOf(tokenId) == msg.sender, "Caller is not the owner of the NFT");

        _nftContract.safeTransferFrom(msg.sender, address(this), tokenId); // Transfer the token to the marketplace
        _listings[tokenId] = Listing(msg.sender, tokenId, price, true);
        
        emit ListingCreated(msg.sender, tokenId, price);
    }

    /**
     * @dev Changes the price of a listed NFT.
     * @param tokenId The ID of the token.
     * @param newPrice The new price for the token.
     */
    function changePrice(uint256 tokenId, uint256 newPrice) external {
        require(_listings[tokenId].active, "NFT is not listed");
        require(_listings[tokenId].seller == msg.sender, "Caller is not the seller");

        _listings[tokenId].price = newPrice;

        emit ListingPriceChanged(tokenId, newPrice);
    }

    /**
     * @dev Removes a listing of an NFT.
     * @param tokenId The ID of the token to be unlisted.
     */
    function removeListing(uint256 tokenId) external {
        require(_listings[tokenId].active, "NFT is not listed");
        require(_listings[tokenId].seller == msg.sender, "Caller is not the seller");

        _nftContract.safeTransferFrom(address(this), msg.sender, tokenId); // Transfer the token back to the seller
        delete _listings[tokenId];

        emit ListingRemoved(tokenId);
    }

    /**
     * @dev Buys an NFT from the marketplace.
     * @param tokenId The ID of the token to be bought.
     */
    function buyNFT(uint256 tokenId) external payable {
        Listing storage listing = _listings[tokenId];
        require(listing.active, "NFT is not listed");
        require(msg.sender != listing.seller, "Caller is the seller");
        require(msg.value == listing.price, "Invalid payment amount");

        address payable seller = payable(listing.seller);
        uint256 marketplaceFee = (listing.price * _feePercentage) / 100;
        uint256 paymentAmount = listing.price - marketplaceFee;

        seller.transfer(paymentAmount); // Transfer payment to the seller
        _owner.transfer(marketplaceFee); // Transfer marketplace fee to the owner
        _nftContract.safeTransferFrom(address(this), msg.sender, tokenId); // Transfer the token to the buyer
        delete _listings[tokenId];

        emit NFTSold(tokenId, listing.seller, msg.sender, listing.price);
    }

    /**
     * @dev ERC721 receiver function to handle incoming token transfers.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}