// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Address.sol";
import "./StorageLayout.sol";

contract Proxy is StorageLayout {
    using Address for address;

    event ImplementationProposed(address indexed newImplementation);
    event Upgraded(address indexed newImplementation);
    event UpgradeCancelled(address indexed cancelledImplementation);

    constructor(
        address _implementation, 
        address _governanceContract,
        uint256 _upgradeDelay
    ) {
        require(_implementation.code.length > 0, "Implementation must be contract");
        require(_governanceContract.code.length > 0, "Governance must be contract");
        implementation = _implementation;
        governanceContract = _governanceContract;
        upgradeDelay = _upgradeDelay;
    }

    modifier onlyGovernance() {
        require(msg.sender == governanceContract, "Only governance can call");
        _;
    }

    // Two-step upgrade process
    function proposeUpgrade(address newImplementation) external onlyGovernance {
        require(newImplementation != address(0), "Invalid implementation");
        require(newImplementation.code.length > 0, "Must be contract");
        require(pendingImplementation == address(0), "Upgrade already pending");
        
        pendingImplementation = newImplementation;
        upgradeProposedTime = block.timestamp;
        
        emit ImplementationProposed(newImplementation);
    }

    function cancelUpgrade() external onlyGovernance {
        address cancelledImpl = pendingImplementation;
        pendingImplementation = address(0);
        upgradeProposedTime = 0;
        emit UpgradeCancelled(cancelledImpl);
    }

    function finalizeUpgrade() external onlyGovernance {
        require(pendingImplementation != address(0), "No upgrade pending");
        require(
            block.timestamp >= upgradeProposedTime + upgradeDelay,
            "Upgrade delay not passed"
        );

        address newImplementation = pendingImplementation;
        implementation = newImplementation;
        
        // Clear pending state
        pendingImplementation = address(0);
        upgradeProposedTime = 0;
        
        emit Upgraded(newImplementation);
    }

    // Improved fallback function with better error handling
    fallback() external payable {
        address _implementation = implementation;
        require(_implementation != address(0), "Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                // Bubble up revert reason if provided
                let size := returndatasize()
                revert(0, size)
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    // Only accept ETH if implementation contract can handle it
    receive() external payable {
        require(
            implementation.code.length > 0,
            "Implementation cannot receive ETH"
        );
    }
} 