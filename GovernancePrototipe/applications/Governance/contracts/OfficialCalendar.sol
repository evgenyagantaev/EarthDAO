// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./StorageLayout.sol";

/**
 * @title OfficialCalendar
 * @dev Утилитарный контракт для работы с HTML5 календарём.
 *      - Контракт не имеет владельца – все привилегированные операции (изменение URL, апгрейд)
 *        доступны только через вызовы от адреса governance (через соответствующее голосование).
 *      - Доступ к функции getCalendarURL() свободный для всех.
 *      - Контракт реализован по схеме UUPS – модификация возможна только через его прокси.
 *      - Контракт можно добавить в реестр utility-контрактов в governance.
 */
contract OfficialCalendar is Initializable, UUPSUpgradeable, StorageLayout {
    /// @notice Событие инициализации
    event Initialized(address governanceContract);
    /// @notice Событие обновления URL календаря
    event CalendarURLUpdated(string newURL);

    // Храним URL HTML5 календаря (например, адрес приложения или IPFS‑хэш)
    string public calendarURL;

    /// @dev Модификатор, разрешающий вызовы только от контракта управления.
    modifier onlyGovernance() {
        require(msg.sender == governanceContract, "OfficialCalendar: Only governance can call");
        _;
    }

    /**
     * @notice Инициализация контракта.
     * @param _governanceContract Адрес контракта управления (governance).
     * @param _initialURL Изначальный URL HTML5 календаря.
     */
    function initialize(address _governanceContract, string memory _initialURL) external initializer {
        require(_governanceContract != address(0), "OfficialCalendar: Invalid governance address");
        governanceContract = _governanceContract;
        calendarURL = _initialURL;
        version = 1;
        emit Initialized(_governanceContract);
    }

    /**
     * @notice Возвращает URL HTML5 календаря.
     * @dev Функция доступна для всех, без проверки владения NFT.
     */
    function getCalendarURL() external view returns (string memory) {
        return calendarURL;
    }

    /**
     * @notice Обновляет URL HTML5 календаря.
     * @dev Доступна только через вызов от governance.
     * @param newURL Новый URL календаря.
     */
    function updateCalendarURL(string memory newURL) external onlyGovernance {
        calendarURL = newURL;
        emit CalendarURLUpdated(newURL);
    }
    
    /**
     * @notice Возвращает идентификатор утилитарного контракта.
     * @dev Позволяет при регистрации в реестре governance однозначно идентифицировать контракт.
     */
    function getUtilityIdentifier() external pure returns (string memory) {
        return "OfficialCalendar";
    }

    /**
     * @dev Функция авторизации апгрейда (UUPS).
     *      Разрешает апгрейд только через governance.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}
}
