// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title GovernanceProxy
 * @dev Минимальный прокси для контракта Governance.
 *      Адрес реализации хранится в слоте согласно стандарту EIP‑1967.
 */
contract GovernanceProxy {
    // EIP-1967: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Конструктор прокси.
     * @param _implementation Адрес контракта-реализации (Governance).
     * @param _data Данные для инициализации реализации (например, вызов initialize).
     *              Если _data не пустой, производится делегированный вызов.
     */
    constructor(address _implementation, bytes memory _data) payable {
        require(_implementation != address(0), "Implementation address cannot be zero");
        assembly {
            sstore(IMPLEMENTATION_SLOT, _implementation)
        }
        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    /**
     * @dev Фолбэк, делегирующий вызовы на реализацию.
     */
    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    /**
     * @dev Делегирует вызов текущей реализации.
     */
    function _delegate() internal {
        address impl;
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
        require(impl != address(0), "Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @notice Позволяет прочитать адрес текущей реализации.
     */
    function getImplementation() external view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }
}
