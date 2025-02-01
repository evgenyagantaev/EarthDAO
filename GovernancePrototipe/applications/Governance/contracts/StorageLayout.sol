// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract StorageLayout {
    // Proxy storage variables
    address public implementation;
    address public pendingImplementation;
    uint256 public upgradeDelay;
    uint256 public upgradeProposedTime;
    
    // Implementation storage variables
    address public governanceContract;
    IERC721 public votingToken;
    bool private initialized;
    uint256 public version;
} 