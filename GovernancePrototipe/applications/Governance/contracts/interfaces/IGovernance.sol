// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IGovernance {
    struct Proposal {
        address target;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        uint256 snapshotBlock;
    }

    event ProposalCreated(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    function votingToken() external view returns (address);
    function proposals(uint256 proposalId) external view returns (Proposal memory);
    function createProposal(address target, bytes memory data) external returns (uint256);
    function vote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;
    function getVotingPower(address voter, uint256 proposalId) external view returns (uint256);
} 