const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace", function () {
  let owner;
  let user1;
  let user2;
  let marketplace;

  before(async () => {
    [owner, user1, user2] = await ethers.getSigners();

    const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
    marketplace = await NFTMarketplace.deploy();
    await marketplace.deployed();
  });

  it("Should list an NFT for sale", async () => {
    // Deploy an ERC721 mock contract for testing
    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    const nft = await ERC721Mock.deploy("Test NFT", "TNFT");
    await nft.deployed();

    // Mint an NFT and approve the marketplace to transfer it
    await nft.mint(user1.address, 1);
    await nft.connect(user1).approve(marketplace.address, 1);

    // List the NFT for sale
    await marketplace.listNFTForSale(nft.address, 1, ethers.utils.parseEther("0.01"));

    const listing = await marketplace.getNFTListing(1);
    expect(listing.nftAddress).to.equal(nft.address);
    expect(listing.tokenId).to.equal(1);
    expect(listing.seller).to.equal(user1.address);
    expect(listing.price).to.equal(ethers.utils.parseEther("0.01"));
    expect(listing.isActive).to.be.true;
  });

  it("Should allow a user to buy an NFT", async () => {
    const listing = await marketplace.getNFTListing(1);
    await expect(() =>
      marketplace.buyNFT(1, { value: listing.price })
    ).to.changeEtherBalance(user2, listing.price);

    const updatedListing = await marketplace.getNFTListing(1);
    expect(updatedListing.isActive).to.be.false;
  });

  it("Should not allow the seller to buy their own NFT", async () => {
    const listing = await marketplace.getNFTListing(1);
    await expect(
      marketplace.buyNFT(1, { value: listing.price, from: user1.address })
    ).to.be.revertedWith("seller cannot buy");
  });

  // Add more test cases for other contract functions as needed

  // Example test cases for auctions
  it("Should list an NFT for auction", async () => {
    // Deploy an ERC721 mock contract for testing
    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    const nft = await ERC721Mock.deploy("Test NFT", "TNFT");
    await nft.deployed();

    // Mint an NFT and approve the marketplace to transfer it
    await nft.mint(user1.address, 2);
    await nft.connect(user1).approve(marketplace.address, 2);

    // List the NFT for auction
    await marketplace.listForAuction(
      nft.address,
      2,
      ethers.utils.parseEther("0.05"),
      3600 // Auction duration in seconds
    );

    const auction = await marketplace.getNFTAuction(1);
    expect(auction.nftAddress).to.equal(nft.address);
    expect(auction.tokenId).to.equal(2);
    expect(auction.seller).to.equal(user1.address);
    expect(auction.reservePrice).to.equal(ethers.utils.parseEther("0.05"));
    expect(auction.isActive).to.be.true;
  });

  // Example test case for withdrawing an auction by the marketplace owner
  it("Should allow the marketplace owner to withdraw an auction", async () => {
    const auction = await marketplace.getNFTAuction(1);
    await expect(() =>
      marketplace.withdrawAuctionNFT(1)
    ).to.changeEtherBalance(user1, auction.highestBid);

    const updatedAuction = await marketplace.getNFTAuction(1);
    expect(updatedAuction.isActive).to.be.false;
  });
});
