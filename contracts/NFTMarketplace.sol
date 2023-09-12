// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}

interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract NFTMarketplace {
    using SafeMath for uint256;
    uint256 salecounter = 1;
    uint256 aucounter = 1;
    address marketOwner;
    uint256 marketFees = 0.001 ether;
    // Structure to represent a listed NFT item
    struct NFTListing {
        IERC721 nftAddress;
        uint256 tokenId;
        address seller;
        uint256 price;
        bool isActive;
    }
    // Mapping from token ID to its listing
    mapping(uint256 => NFTListing) public nftListings;
    struct AuctionListing {
        IERC721 nftAddress;
        address seller;
        uint256 tokenId;
        uint256 reservePrice;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
    }
    mapping(uint256 => AuctionListing) public AuctionListings;
    // Events
    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event NFTSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 reservePrice,
        uint256 auctionEndTime
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 highestBid
    );
    event Bid(uint256 auctionId, address bidder, uint256 bidValue);

    constructor() {
        marketOwner = msg.sender;
    }

    // List an NFT for sale
    function listNFTForSale(
        address _nftAddress,
        uint256 tokenId,
        uint256 price
    ) external {
        IERC721 nftAddress = IERC721(_nftAddress);
        require(
            nftAddress.ownerOf(tokenId) == msg.sender,
            "You don't own this NFT"
        );
        require(price > marketFees, "price greater than 0.0001ether");
        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);
        nftListings[salecounter] = NFTListing(
            nftAddress,
            tokenId,
            msg.sender,
            price,
            true
        );
        emit NFTListed(tokenId, msg.sender, price);
        salecounter++;
    }

    // Buy an NFT
    function buyNFT(uint256 saleId) external payable {
        NFTListing storage list = nftListings[saleId];
        require(list.isActive, "NFT is not listed");
        require(msg.value == list.price, "Insufficient funds");
        require(msg.sender != list.seller, "seller cannot buy");
        // Transfer the NFT to the buyer
        list.nftAddress.safeTransferFrom(
            address(this),
            msg.sender,
            list.tokenId
        );
        uint256 price = list.price.sub(marketFees);
        payable(marketOwner).transfer(marketFees);
        // Transfer the payment to the seller
        payable(list.seller).transfer(price);
        // Deactivate the listing
        list.isActive = false;
        emit NFTSold(list.tokenId, list.seller, msg.sender, list.price);
    }

    function unlistFromSale(uint256 saleId) public {
        require(nftListings[saleId].isActive, "NFT is not listed");
        payable(marketOwner).transfer(marketFees);
        // Transfer the NFT back to the owner
        nftListings[saleId].nftAddress.safeTransferFrom(
            address(this),
            msg.sender,
            nftListings[saleId].tokenId
        );
        // Deactivate the listing
        nftListings[saleId].isActive = false;
    }

    // Get the details of an NFT listing
    function getNFTListing(
        uint256 saleId
    ) external view returns (NFTListing memory) {
        return nftListings[saleId];
    }

    // market owner function
    function withdrawListedNFT(uint256 saleId) public {
        require(msg.sender == marketOwner, "market owner can call");
        require(nftListings[saleId].isActive, "NFT is not listed");
        // Transfer the NFT back to the owner
        nftListings[saleId].nftAddress.safeTransferFrom(
            address(this),
            msg.sender,
            nftListings[saleId].tokenId
        );
        // Deactivate the listing
        nftListings[saleId].isActive = false;
    }

    function listForAuction(
        address _nftAddress,
        uint256 tokenId,
        uint256 reservePrice,
        uint256 auctionEndTime
    ) public {
        IERC721 nftAddress = IERC721(_nftAddress);
        require(
            nftAddress.ownerOf(tokenId) == msg.sender,
            "You don't own this NFT"
        );
        require(reservePrice > marketFees, "price greater than 0.0001ether");
        nftAddress.safeTransferFrom(msg.sender, address(this), tokenId);
        auctionEndTime = block.timestamp.add(auctionEndTime);
        AuctionListings[aucounter] = AuctionListing(
            nftAddress,
            msg.sender,
            tokenId,
            reservePrice,
            auctionEndTime,
            address(0),
            reservePrice,
            true
        );
        emit AuctionCreated(
            aucounter,
            msg.sender,
            tokenId,
            reservePrice,
            auctionEndTime
        );
        aucounter++;
    }

    function placeBid(uint256 auctionId) external payable {
        require(
            msg.value > AuctionListings[auctionId].highestBid,
            "Bid must be higher than the current highest bid"
        );
        require(
            msg.sender != AuctionListings[auctionId].seller,
            "Seller cannot bid"
        );
        require(aucounter >= auctionId, "invalid auction ID");
        payable(AuctionListings[auctionId].highestBidder).transfer(
            AuctionListings[auctionId].highestBid
        );
        payable(address(this)).transfer(msg.value);
        AuctionListings[auctionId].highestBid = msg.value;
        AuctionListings[auctionId].highestBidder = msg.sender;
        emit Bid(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) public {
        require(
            block.timestamp >= AuctionListings[auctionId].auctionEndTime,
            "Auction has not ended yet"
        );
        require(
            AuctionListings[auctionId].isActive == false,
            "not list for auction"
        );
        // Mark the auction as ended
        AuctionListings[auctionId].isActive = false;
        payable(AuctionListings[auctionId].seller).transfer(
            AuctionListings[auctionId].highestBid
        );
        AuctionListings[auctionId].nftAddress.safeTransferFrom(
            address(this),
            msg.sender,
            AuctionListings[auctionId].tokenId
        );
        emit AuctionEnded(
            auctionId,
            AuctionListings[auctionId].highestBidder,
            AuctionListings[auctionId].highestBid
        );
    }

    // Get the details of an NFT auction
    function getNFTAuction(
        uint256 auctionId
    ) external view returns (AuctionListing memory) {
        return AuctionListings[auctionId];
    }

    // marketplace owner withdraw function
    function withdrawAuctionNFT(uint256 auctionId) public {
        require(msg.sender == marketOwner, "market owner can call");
        require(AuctionListings[auctionId].isActive, "NFT is not listed");
        payable(AuctionListings[auctionId].highestBidder).transfer(
            AuctionListings[auctionId].highestBid
        );
        // Transfer the NFT back to the owner
        AuctionListings[auctionId].nftAddress.safeTransferFrom(
            address(this),
            msg.sender,
            AuctionListings[auctionId].tokenId
        );
        // Deactivate the listing
        AuctionListings[auctionId].isActive = false;
    }
}
