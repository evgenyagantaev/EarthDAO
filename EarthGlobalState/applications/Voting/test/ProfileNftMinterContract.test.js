const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ProfileNftMinterContract", function () {
  let profileNftMinter;
  let owner;
  let user;

  beforeEach(async function () {
    // Получаем тестовые аккаунты
    [owner, user] = await ethers.getSigners();

    // Деплоим контракт
    const ProfileNftMinterContract = await ethers.getContractFactory("ProfileNftMinterContract");
    profileNftMinter = await ProfileNftMinterContract.deploy();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await profileNftMinter.owner()).to.equal(owner.address);
    });

    it("Should have correct name and symbol", async function () {
      expect(await profileNftMinter.name()).to.equal("GlobalFreeLaborExchangeProfile");
      expect(await profileNftMinter.symbol()).to.equal("GFLEP");
    });
  });

  describe("Minting", function () {
    const tokenURI = "ipfs://QmTest";

    it("Should allow users to mint NFT", async function () {
      await profileNftMinter.connect(user).safeMint(tokenURI);
      
      expect(await profileNftMinter.ownerOf(0)).to.equal(user.address);
      expect(await profileNftMinter.tokenURI(0)).to.equal(tokenURI);
    });

    it("Should increment token ID correctly", async function () {
      await profileNftMinter.connect(user).safeMint(tokenURI);
      await profileNftMinter.connect(user).safeMint(tokenURI);
      
      expect(await profileNftMinter.ownerOf(1)).to.equal(user.address);
    });
  });

  describe("Burning", function () {
    const tokenURI = "ipfs://QmTest";

    it("Should allow token owner to burn their NFT", async function () {
      await profileNftMinter.connect(user).safeMint(tokenURI);
      await profileNftMinter.connect(user).burn(0);

      await expect(profileNftMinter.ownerOf(0)).to.be.revertedWith(
        "ERC721: invalid token ID"
      );
    });

    it("Should not allow non-owner to burn NFT", async function () {
      await profileNftMinter.connect(user).safeMint(tokenURI);
      
      await expect(
        profileNftMinter.connect(owner).burn(0)
      ).to.be.revertedWith("ERC721: caller is not token owner or approved");
    });
  });

  describe("Token URI", function () {
    const tokenURI = "ipfs://QmTest";

    it("Should return correct token URI", async function () {
      await profileNftMinter.connect(user).safeMint(tokenURI);
      expect(await profileNftMinter.tokenURI(0)).to.equal(tokenURI);
    });

    it("Should revert for non-existent token", async function () {
      await expect(
        profileNftMinter.tokenURI(99)
      ).to.be.revertedWith("ERC721: invalid token ID");
    });
  });
}); 