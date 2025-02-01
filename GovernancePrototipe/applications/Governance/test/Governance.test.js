const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance", function () {
    let governance;
    let votingToken;
    let implementation;
    let proxy;
    let owner;
    let addr1;
    let addr2;

    beforeEach(async function () {
        // Get signers
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy mock ERC721 token
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        votingToken = await MockERC721.deploy("VotingToken", "VOTE");
        await votingToken.deployed();

        // Deploy Governance
        const Governance = await ethers.getContractFactory("Governance");
        governance = await Governance.deploy(
            votingToken.address,
            1, // voteWeightPerToken
            10, // quorumPercentage
            86400 // votingPeriod (1 day)
        );
        await governance.deployed();

        // Deploy Implementation
        const Implementation = await ethers.getContractFactory("Implementation");
        implementation = await Implementation.deploy();
        await implementation.deployed();

        // Deploy Proxy
        const Proxy = await ethers.getContractFactory("Proxy");
        proxy = await Proxy.deploy(
            implementation.address,
            governance.address,
            86400 // upgradeDelay
        );
        await proxy.deployed();
    });

    describe("Proposal Creation", function () {
        it("Should create a proposal", async function () {
            // Mint some tokens to addr1
            await votingToken.mint(addr1.address, 1);
            
            const target = implementation.address;
            const data = "0x";
            
            await expect(governance.connect(addr1).createProposal(target, data))
                .to.emit(governance, "ProposalCreated")
                .withArgs(1); // First proposal ID should be 1
                
            const proposal = await governance.proposals(1);
            expect(proposal.target).to.equal(target);
            expect(proposal.data).to.equal(data);
            expect(proposal.executed).to.equal(false);
        });
    });

    describe("Voting", function () {
        beforeEach(async function () {
            // Mint tokens and create proposal
            await votingToken.mint(addr1.address, 1);
            await votingToken.mint(addr2.address, 1);
            await governance.connect(addr1).createProposal(implementation.address, "0x");
        });

        it("Should allow token holders to vote", async function () {
            await expect(governance.connect(addr1).vote(1, true))
                .to.emit(governance, "Voted")
                .withArgs(1, addr1.address, true, 1);

            const proposal = await governance.proposals(1);
            expect(proposal.votesFor).to.equal(1);
        });

        it("Should prevent double voting", async function () {
            await governance.connect(addr1).vote(1, true);
            await expect(
                governance.connect(addr1).vote(1, true)
            ).to.be.revertedWith("Already voted");
        });
    });

    describe("Proposal Execution", function () {
        beforeEach(async function () {
            await votingToken.mint(addr1.address, 5); // 50% of tokens
            await votingToken.mint(addr2.address, 5); // 50% of tokens
            await governance.connect(addr1).createProposal(implementation.address, "0x");
        });

        it("Should execute proposal after quorum and majority", async function () {
            await governance.connect(addr1).vote(1, true);
            await governance.connect(addr2).vote(1, true);

            // Fast forward time
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);

            await expect(governance.executeProposal(1))
                .to.emit(governance, "ProposalExecuted")
                .withArgs(1);
        });

        it("Should not execute proposal before voting period ends", async function () {
            await governance.connect(addr1).vote(1, true);
            await governance.connect(addr2).vote(1, true);

            await expect(
                governance.executeProposal(1)
            ).to.be.revertedWith("Voting period not ended");
        });
    });

    describe("Parameter Updates", function () {
        it("Should update vote weight", async function () {
            await expect(governance.updateVoteWeight(2))
                .to.emit(governance, "VoteWeightUpdated")
                .withArgs(1, 2);
            
            expect(await governance.voteWeightPerToken()).to.equal(2);
        });

        it("Should update quorum", async function () {
            await expect(governance.updateQuorum(20))
                .to.emit(governance, "QuorumUpdated")
                .withArgs(10, 20);
            
            expect(await governance.quorumPercentage()).to.equal(20);
        });
    });

    describe("Proxy Upgrades", function () {
        it("Should propose and finalize upgrade", async function () {
            const NewImplementation = await ethers.getContractFactory("Implementation");
            const newImplementation = await NewImplementation.deploy();
            await newImplementation.deployed();

            await expect(proxy.connect(governance).proposeUpgrade(newImplementation.address))
                .to.emit(proxy, "ImplementationProposed")
                .withArgs(newImplementation.address);

            // Fast forward time
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);

            await expect(proxy.connect(governance).finalizeUpgrade())
                .to.emit(proxy, "Upgraded")
                .withArgs(newImplementation.address);

            expect(await proxy.implementation()).to.equal(newImplementation.address);
        });
    });
});

describe("Governance Advanced Tests", function () {
    describe("Voting Power Snapshots", function () {
        it("Should use snapshot of voting power at proposal creation", async function () {
            await votingToken.mint(addr1.address, 1);
            await governance.connect(addr1).createProposal(implementation.address, "0x");
            
            // Transfer token after proposal creation
            await votingToken.connect(addr1).transferFrom(addr1.address, addr2.address, 1);
            
            // Original owner should still be able to vote with snapshot power
            await expect(governance.connect(addr1).vote(1, true))
                .to.emit(governance, "Voted")
                .withArgs(1, addr1.address, true, 1);
            
            // New owner shouldn't have voting power for this proposal
            await expect(
                governance.connect(addr2).vote(1, true)
            ).to.be.revertedWith("No voting power");
        });

        it("Should correctly track multiple proposals' voting power", async function () {
            await votingToken.mint(addr1.address, 2);
            
            // Create first proposal
            await governance.connect(addr1).createProposal(implementation.address, "0x");
            
            // Transfer one token
            await votingToken.connect(addr1).transferFrom(addr1.address, addr2.address, 1);
            
            // Create second proposal
            await governance.connect(addr1).createProposal(implementation.address, "0x");
            
            // Check voting power for both proposals
            expect(await governance.getVotingPower(addr1.address, 1)).to.equal(2);
            expect(await governance.getVotingPower(addr1.address, 2)).to.equal(1);
        });
    });

    describe("Proposal Cancellation", function () {
        beforeEach(async function () {
            await votingToken.mint(addr1.address, 1);
            await governance.connect(addr1).createProposal(implementation.address, "0x");
        });

        it("Should allow governance to cancel proposal", async function () {
            await expect(governance.cancelProposal(1))
                .to.emit(governance, "ProposalCancelled")
                .withArgs(1);
            
            await expect(
                governance.executeProposal(1)
            ).to.be.revertedWith("Proposal was cancelled");
        });

        it("Should not allow voting on cancelled proposal", async function () {
            await governance.cancelProposal(1);
            await expect(
                governance.connect(addr1).vote(1, true)
            ).to.be.revertedWith("Proposal was cancelled");
        });

        it("Should not allow cancelling executed proposal", async function () {
            await votingToken.mint(addr2.address, 9); // Total 10 tokens for quorum
            await governance.connect(addr1).vote(1, true);
            await governance.connect(addr2).vote(1, true);
            
            // Fast forward time
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);
            
            await governance.executeProposal(1);
            
            await expect(
                governance.cancelProposal(1)
            ).to.be.revertedWith("Proposal already executed");
        });
    });

    describe("Quorum and Voting Thresholds", function () {
        beforeEach(async function () {
            // Mint 10 tokens total (quorum is 10%)
            await votingToken.mint(addr1.address, 5);
            await votingToken.mint(addr2.address, 5);
            await governance.connect(addr1).createProposal(implementation.address, "0x");
        });

        it("Should fail execution if quorum not met", async function () {
            // Only 5% voting (need 10%)
            await governance.connect(addr1).vote(1, true);
            
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);
            
            await expect(
                governance.executeProposal(1)
            ).to.be.revertedWith("Quorum not reached");
        });

        it("Should fail if votes against > votes for", async function () {
            await governance.connect(addr1).vote(1, true); // 5 votes for
            await governance.connect(addr2).vote(1, false); // 5 votes against
            
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);
            
            await expect(
                governance.executeProposal(1)
            ).to.be.revertedWith("Proposal not passed");
        });

        it("Should pass with exact quorum and majority", async function () {
            // 10% voting (exact quorum) with majority
            await governance.connect(addr1).vote(1, true);
            await governance.connect(addr2).vote(1, true);
            
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);
            
            await expect(governance.executeProposal(1))
                .to.emit(governance, "ProposalExecuted")
                .withArgs(1);
        });
    });

    describe("Parameter Updates Edge Cases", function () {
        it("Should reject invalid vote weights", async function () {
            await expect(
                governance.updateVoteWeight(0)
            ).to.be.revertedWith("Weight must be positive");
        });

        it("Should reject invalid quorum values", async function () {
            await expect(
                governance.updateQuorum(0)
            ).to.be.revertedWith("Invalid quorum percentage");
            
            await expect(
                governance.updateQuorum(101)
            ).to.be.revertedWith("Invalid quorum percentage");
        });

        it("Should reject invalid voting periods", async function () {
            await expect(
                governance.updateVotingPeriod(0)
            ).to.be.revertedWith("Period must be positive");
        });

        it("Should affect only new proposals after parameter updates", async function () {
            // Create proposal with original parameters
            await votingToken.mint(addr1.address, 1);
            await governance.connect(addr1).createProposal(implementation.address, "0x");
            
            // Update parameters
            await governance.updateVoteWeight(2);
            await governance.updateQuorum(20);
            await governance.updateVotingPeriod(172800); // 2 days
            
            // Create new proposal
            await governance.connect(addr1).createProposal(implementation.address, "0x");
            
            // Check old proposal still uses old parameters
            const oldProposal = await governance.proposals(1);
            const newProposal = await governance.proposals(2);
            
            expect(oldProposal.deadline - oldProposal.snapshotBlock * 15)
                .to.be.lessThan(newProposal.deadline - newProposal.snapshotBlock * 15);
        });
    });

    describe("Proxy Upgrade Security", function () {
        it("Should not allow non-governance to propose upgrade", async function () {
            const NewImplementation = await ethers.getContractFactory("Implementation");
            const newImplementation = await NewImplementation.deploy();
            
            await expect(
                proxy.connect(addr1).proposeUpgrade(newImplementation.address)
            ).to.be.revertedWith("Only governance can call");
        });

        it("Should not allow finalizing upgrade before delay", async function () {
            const NewImplementation = await ethers.getContractFactory("Implementation");
            const newImplementation = await NewImplementation.deploy();
            
            await proxy.connect(governance).proposeUpgrade(newImplementation.address);
            
            await expect(
                proxy.connect(governance).finalizeUpgrade()
            ).to.be.revertedWith("Upgrade delay not passed");
        });

        it("Should allow cancelling pending upgrade", async function () {
            const NewImplementation = await ethers.getContractFactory("Implementation");
            const newImplementation = await NewImplementation.deploy();
            
            await proxy.connect(governance).proposeUpgrade(newImplementation.address);
            await expect(proxy.connect(governance).cancelUpgrade())
                .to.emit(proxy, "UpgradeCancelled");
            
            // Try to finalize cancelled upgrade
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine", []);
            
            await expect(
                proxy.connect(governance).finalizeUpgrade()
            ).to.be.revertedWith("No upgrade pending");
        });
    });
}); 