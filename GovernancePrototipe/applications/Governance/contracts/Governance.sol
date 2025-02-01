// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IImplementation {
    function initialize(address _governanceContract) external;
}

/**
 * @title Governance
 * @dev Контракт для децентрализованного управления.
 */
contract Governance is ReentrancyGuard {
    struct Proposal {
        address target;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        uint256 snapshotBlock;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    IERC721Enumerable public votingToken;

    uint256 public voteWeightPerToken;
    uint256 public quorumPercentage;
    uint256 public votingPeriod;
    
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public snapshotVotingPower;
    
    event VoteWeightUpdated(uint256 oldWeight, uint256 newWeight);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);
    event VotingPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    event ProposalCreated(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    mapping(uint256 => bool) public cancelled;

    // --- Реестр utility-контрактов ---
    address[] public utilityContracts;
    mapping(address => bool) public isUtilityContract;

    event UtilityContractAdded(address indexed utilityContract);
    event UtilityContractRemoved(address indexed utilityContract);
    event UtilityContractReplaced(address indexed oldUtilityContract, address indexed newUtilityContract);

    constructor(
        address _votingToken,
        uint256 _voteWeightPerToken,
        uint256 _quorumPercentage,
        uint256 _votingPeriod
    ) {
        votingToken = IERC721Enumerable(_votingToken);
        voteWeightPerToken = _voteWeightPerToken;
        quorumPercentage = _quorumPercentage;
        votingPeriod = _votingPeriod;
    }

    function getTotalVotingPower() public view returns (uint256) {
        uint256 supply = votingToken.totalSupply();
        return supply * voteWeightPerToken;
    }

    function createProposal(address target, bytes memory data) external returns (uint256) {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            target: target,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + votingPeriod,
            executed: false,
            snapshotBlock: block.number
        });

        emit ProposalCreated(proposalCount);
        return proposalCount;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        uint256 votingPower;
        if (snapshotVotingPower[proposalId][msg.sender] > 0) {
            votingPower = snapshotVotingPower[proposalId][msg.sender];
        } else {
            votingPower = votingToken.balanceOf(msg.sender) * voteWeightPerToken;
            snapshotVotingPower[proposalId][msg.sender] = votingPower;
        }
        
        require(votingPower > 0, "No voting power");
        
        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, support, votingPower);
    }

    /// @dev Модификатор, разрешающий вызов функции только через голосование (т.е. если вызов сделан самим контрактом).
    modifier onlyGovernance() {
        require(msg.sender == address(this), "Only governance can call");
        _;
    }

    function cancelProposal(uint256 proposalId) external onlyGovernance {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");
        require(!cancelled[proposalId], "Proposal already cancelled");
        
        cancelled[proposalId] = true;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Выполнение предложения с защитой от повторных вызовов (reentrancy).
     * @dev Функция отмечает предложение как исполненное до выполнения внешнего вызова,
     *      что соответствует паттерну "checks-effects-interactions".
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(!cancelled[proposalId], "Proposal was cancelled");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 minQuorum = (getTotalVotingPower() * quorumPercentage) / 100;
        require(totalVotes >= minQuorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal not passed");

        // Обновляем состояние до внешнего вызова
        proposal.executed = true;
        
        // Выполняем внешний вызов
        (bool success, ) = proposal.target.call(proposal.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    function updateVoteWeight(uint256 newWeight) external onlyGovernance {
        require(newWeight > 0, "Weight must be positive");
        emit VoteWeightUpdated(voteWeightPerToken, newWeight);
        voteWeightPerToken = newWeight;
    }

    function updateQuorum(uint256 newQuorum) external onlyGovernance {
        require(newQuorum > 0 && newQuorum <= 100, "Invalid quorum percentage");
        emit QuorumUpdated(quorumPercentage, newQuorum);
        quorumPercentage = newQuorum;
    }

    function updateVotingPeriod(uint256 newPeriod) external onlyGovernance {
        require(newPeriod > 0, "Period must be positive");
        emit VotingPeriodUpdated(votingPeriod, newPeriod);
        votingPeriod = newPeriod;
    }

    function getVotingPower(address voter, uint256 proposalId) public view returns (uint256) {
        if (snapshotVotingPower[proposalId][voter] > 0) {
            return snapshotVotingPower[proposalId][voter];
        }
        return votingToken.balanceOf(voter) * voteWeightPerToken;
    }

    // ============================================
    // Реестр Utility-контрактов
    // ============================================

    function addUtilityContract(address _utilityContract) external onlyGovernance {
        require(_utilityContract != address(0), "Invalid contract address");
        require(_utilityContract.code.length > 0, "Address has no code");
        require(!isUtilityContract[_utilityContract], "Already registered");

        utilityContracts.push(_utilityContract);
        isUtilityContract[_utilityContract] = true;
        emit UtilityContractAdded(_utilityContract);
    }

    function removeUtilityContract(address _utilityContract) external onlyGovernance {
        require(isUtilityContract[_utilityContract], "Not registered");

        isUtilityContract[_utilityContract] = false;

        for (uint i = 0; i < utilityContracts.length; i++) {
            if (utilityContracts[i] == _utilityContract) {
                utilityContracts[i] = utilityContracts[utilityContracts.length - 1];
                utilityContracts.pop();
                break;
            }
        }
        emit UtilityContractRemoved(_utilityContract);
    }

    function replaceUtilityContract(address _oldUtility, address _newUtility) external onlyGovernance {
        require(isUtilityContract[_oldUtility], "Old utility not registered");
        require(_newUtility != address(0), "Invalid new contract address");
        require(_newUtility.code.length > 0, "New address has no code");
        require(!isUtilityContract[_newUtility], "New utility already registered");

        for (uint i = 0; i < utilityContracts.length; i++) {
            if (utilityContracts[i] == _oldUtility) {
                utilityContracts[i] = _newUtility;
                break;
            }
        }
        isUtilityContract[_oldUtility] = false;
        isUtilityContract[_newUtility] = true;
        emit UtilityContractReplaced(_oldUtility, _newUtility);
    }
}
