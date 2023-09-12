const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("NFTFactory", function () {
    let NFTFactory;
    let nftFactory;
    let MyNFT;
    let myNFT;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        NFTFactory = await ethers.getContractFactory("NFTFactory");
        nftFactory = await NFTFactory.connect(owner).deploy();

        MyNFT = await ethers.getContractFactory("MyNFT");

        // Create a new NFT contract
        await nftFactory.connect(owner).createNFT("MyNFT", "MNFT");
        const events = await nftFactory.queryFilter("NFTCreated");
        const nftContractAddress = events[0].args.nftContract;
        myNFT = await MyNFT.attach(nftContractAddress);
    });

    it("should create a new NFT contract", async function () {
        const name = await myNFT.name();
        const symbol = await myNFT.symbol();
        expect(name).to.equal("MyNFT");
        expect(symbol).to.equal("MNFT");
    });

    it("should mint NFTs to the owner", async function () {
        const ownerBalanceBefore = await myNFT.balanceOf(owner.address);
        expect(ownerBalanceBefore).to.equal(1);

        // Mint another NFT
        await myNFT.connect(owner).mint(user.address);

        const ownerBalanceAfter = await myNFT.balanceOf(owner.address);
        expect(ownerBalanceAfter).to.equal(2);

        const userBalance = await myNFT.balanceOf(user.address);
        expect(userBalance).to.equal(0);
    });

    it("should not allow non-owners to mint NFTs", async function () {
        await expect(myNFT.connect(user).mint(user.address)).to.be.revertedWith(
            "creator can mint"
        );
    });

    it("should set the correct token URI", async function () {
        const tokenId = 0;
        const tokenURI = "https://example.com/token/0";

        await myNFT.connect(owner).setTokenURI(tokenId, tokenURI);
        const retrievedTokenURI = await myNFT.tokenURI(tokenId);

        expect(retrievedTokenURI).to.equal(tokenURI);
    });
});
