// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title EarthCitizenshipProxy
 * @dev Индивидуальный прокси для EarthCitizenshipToken.
 *      Прокси хранит адрес реализации в слоте по стандарту EIP-1967
 *      и делегирует все вызовы на текущую реализацию.
 */
contract EarthCitizenshipProxy {
    // EIP1967: bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Конструктор прокси.
     * @param _implementation Адрес контракта-реализации (EarthCitizenshipToken).
     * @param _data Данные для инициализации реализации (например, вызов initialize(baseURI)).
     *              Если _data не пустой, происходит делегированный вызов для инициализации.
     */
    constructor(address _implementation, bytes memory _data) payable {
        require(_implementation != address(0), "Implementation address cannot be zero");
        _setImplementation(_implementation);
        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    /**
     * @dev Устанавливает адрес реализации в слоте согласно EIP1967.
     */
    function _setImplementation(address _implementation) internal {
        assembly {
            sstore(IMPLEMENTATION_SLOT, _implementation)
        }
    }

    /**
     * @dev Фолбэк, который делегирует все вызовы на реализацию.
     */
    fallback() external payable {
        _fallback();
    }

    receive() external payable {
        _fallback();
    }

    /**
     * @dev Делегирует вызов текущей реализации.
     */
    function _fallback() internal {
        address impl;
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
        require(impl != address(0), "Implementation not set");

        assembly {
            // Копируем calldata в начало памяти.
            calldatacopy(0, 0, calldatasize())
            // Делегируем вызов.
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // Копируем returndata.
            let size := returndatasize()
            returndatacopy(0, 0, size)
            
            // В зависимости от результата делегированного вызова,
            // либо возвращаем данные, либо выполняем revert.
            switch result
            case 0 { revert(0, size) }
            default { return(0, size) }
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
