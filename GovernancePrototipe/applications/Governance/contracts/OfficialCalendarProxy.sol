// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title OfficialCalendarProxy
 * @dev Custom proxy for OfficialCalendar contract.
 *      Implementation address is stored in slot according to EIP-1967 standard,
 *      and all calls are delegated to it.
 */
contract OfficialCalendarProxy {
    // EIP-1967: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Proxy constructor
     * @param _implementation Implementation contract address (OfficialCalendar)
     * @param _data Initialization data for implementation (e.g., initialize call)
     *              If _data is not empty, delegatecall will be performed
     */
    constructor(address _implementation, bytes memory _data) payable {
        require(_implementation != address(0), "OfficialCalendarProxy: Implementation address cannot be zero");
        assembly {
            sstore(IMPLEMENTATION_SLOT, _implementation)
        }
        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "OfficialCalendarProxy: Initialization failed");
        }
    }

    /**
     * @dev Fallback that delegates calls to implementation
     */
    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    /**
     * @dev Delegates call to current implementation
     */
    function _delegate() internal {
        address impl;
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
        require(impl != address(0), "OfficialCalendarProxy: Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch result
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }

    /**
     * @notice Returns current implementation address
     */
    function getImplementation() external view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }
} 