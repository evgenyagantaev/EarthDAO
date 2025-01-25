// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "basic-dao/@openzeppelin/contracts/governance/Governor.sol";
import "basic-dao/@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "basic-dao/@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "basic-dao/@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract SimpleDAO is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    constructor(
        string memory _name,
        IVotes _token,
        uint256 _quorumThreshold
    )
        Governor(_name)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumThreshold)
    {}

    function votingDelay() public pure override returns (uint256) {
        return 1; // 1 block
    }

    function votingPeriod() public pure override returns (uint256) {
        return 45818; // 1 week
    }

    // The following functions are overrides required by Solidity.

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }
}

