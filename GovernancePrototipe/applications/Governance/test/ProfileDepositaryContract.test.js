const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ProfileDepositaryContract", function () {
  let profileNFT;
  let depositary;
  let owner;
  let user1;
  let user2;
  const TOKEN_ID = 1;

  beforeEach(async function () {
    // Получаем аккаунты для тестирования
    [owner, user1, user2] = await ethers.getSigners();

    // Деплоим тестовый NFT контракт
    const ProfileNFT = await ethers.getContractFactory("ProfileNFT");
    profileNFT = await ProfileNFT.deploy();
    await profileNFT.waitForDeployment();

    // Деплоим контракт депозитария
    const ProfileDepositary = await ethers.getContractFactory("ProfileDepositaryContract");
    depositary = await ProfileDepositary.deploy(await profileNFT.getAddress());
    await depositary.waitForDeployment();

    // Минтим тестовый NFT для user1
    await profileNFT.connect(owner).safeMint(user1.address, TOKEN_ID, "");
  });

  describe("Deployment", function () {
    it("Should set the correct NFT contract address", async function () {
      expect(await depositary.profileNFTContract()).to.equal(await profileNFT.getAddress());
    });
  });

  describe("Depositing", function () {
    beforeEach(async function () {
      // Апрувим депозитарий для управления NFT
      await profileNFT.connect(user1).approve(await depositary.getAddress(), TOKEN_ID);
    });

    it("Should allow depositing NFT", async function () {
      await expect(depositary.connect(user1).depositProfile(TOKEN_ID))
        .to.emit(depositary, "NFTDeposited")
        .withArgs(user1.address, TOKEN_ID);

      expect(await depositary.getDepositedProfileOwner(TOKEN_ID)).to.equal(user1.address);
    });

    it("Should not allow depositing the same NFT twice", async function () {
      await depositary.connect(user1).depositProfile(TOKEN_ID);
      await expect(depositary.connect(user1).depositProfile(TOKEN_ID))
        .to.be.revertedWith("Already deposited");
    });

    it("Should not allow depositing NFT by non-owner", async function () {
      await expect(depositary.connect(user2).depositProfile(TOKEN_ID))
        .to.be.revertedWith("Not the owner");
    });
  });

  describe("Withdrawing", function () {
    beforeEach(async function () {
      await profileNFT.connect(user1).approve(await depositary.getAddress(), TOKEN_ID);
      await depositary.connect(user1).depositProfile(TOKEN_ID);
    });

    it("Should allow withdrawing NFT by depositor", async function () {
      await expect(depositary.connect(user1).withdrawProfile(TOKEN_ID))
        .to.emit(depositary, "NFTWithdrawn")
        .withArgs(user1.address, TOKEN_ID);

      expect(await depositary.getDepositedProfileOwner(TOKEN_ID)).to.equal(ethers.ZeroAddress);
    });

    it("Should not allow withdrawing NFT by non-depositor", async function () {
      await expect(depositary.connect(user2).withdrawProfile(TOKEN_ID))
        .to.be.revertedWith("Not the depositor");
    });

    it("Should not allow withdrawing non-deposited NFT", async function () {
      const NON_EXISTENT_TOKEN_ID = 999;
      await expect(depositary.connect(user1).withdrawProfile(NON_EXISTENT_TOKEN_ID))
        .to.be.revertedWith("Not deposited");
    });
  });

  describe("Getters", function () {
    it("Should correctly return deposited profile IDs", async function () {
      // Минтим и депозитим несколько токенов
      const TOKEN_ID_2 = 2;
      await profileNFT.connect(owner).safeMint(user1.address, TOKEN_ID_2, "");
      
      await profileNFT.connect(user1).approve(await depositary.getAddress(), TOKEN_ID);
      await profileNFT.connect(user1).approve(await depositary.getAddress(), TOKEN_ID_2);
      
      await depositary.connect(user1).depositProfile(TOKEN_ID);
      await depositary.connect(user1).depositProfile(TOKEN_ID_2);

      const depositedIds = await depositary.getDepositedProfileIds();
      expect(depositedIds.length).to.equal(2);
      expect(depositedIds).to.include(TOKEN_ID);
      expect(depositedIds).to.include(TOKEN_ID_2);
    });

    it("Should correctly return deposited profile owner", async function () {
      await profileNFT.connect(user1).approve(await depositary.getAddress(), TOKEN_ID);
      await depositary.connect(user1).depositProfile(TOKEN_ID);

      expect(await depositary.getDepositedProfileOwner(TOKEN_ID)).to.equal(user1.address);
    });
  });
}); 