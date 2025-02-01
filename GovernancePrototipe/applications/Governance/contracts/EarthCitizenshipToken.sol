// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title EarthCitizenshipToken
 * @dev Upgradeable NFT-контракт, реализующий следующие условия:
 *  - Любой пользователь может чеканить токен, если у него его ещё нет.
 *  - Токен при чеканке сразу зачисляется на счет вызвавшего.
 *  - Перевод токена запрещен: разрешены только mint (from == address(0)) и burn (to == address(0)).
 *  - Сжигать токен может только его владелец.
 *  - Контракт поддерживает механизм апгрейда через UUPS, который может быть вызван только владельцем.
 *
 * @notice При инициализации в качестве владельца остается деплоер. Для передачи владения (например, 
 *         прокси‑Governance) необходимо вызвать функцию transferOwnershipToGovernance.
 */
contract EarthCitizenshipToken is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Хранение базового URI для токенов
    string private _baseTokenURI;

    /**
     * @notice Инициализация контракта (заменяет конструктор).
     * @param baseURI Новый базовый URI для токенов.
     */
    function initialize(string memory baseURI) public initializer {
        __ERC721_init("EarthCitizenship", "ECT");
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _baseTokenURI = baseURI;
        // Владелец остается деплоером (msg.sender), передача владения на Governance будет выполнена отдельно.
    }

    /// @notice Чеканит (mint) токен для msg.sender, если у него ещё нет NFT.
    function safeMint() external {
        require(balanceOf(msg.sender) == 0, "Address already has a token");
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(msg.sender, tokenId);
        // Для простоты в качестве tokenURI назначается базовый URI.
        _setTokenURI(tokenId, _baseTokenURI);
    }

    /// @notice Позволяет владельцу обновить базовый URI.
    function setBaseURI(string memory newURI) external onlyOwner {
        _baseTokenURI = newURI;
    }

    // --- Ограничение передачи токена ---
    /**
     * @dev Переопределяем _transfer так, чтобы разрешать только чеканку (from == address(0))
     *      и сжигание (to == address(0)). Все попытки перевода приводят к revert.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(
            from == address(0) || to == address(0),
            "Token is non-transferable"
        );
        super._transfer(from, to, tokenId);
    }

    // --- Необходимые переопределения для ERC721URIStorage ---
    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // --- Функция авторизации апгрейда (UUPS) ---
    /**
     * @dev Разрешает апгрейд контракта только владельцу.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Передает владение токеном на адрес прокси Governance.
     *         Вызывается текущим владельцем (деплоером или уже переданным Governance).
     * @param governanceAddr Новый адрес владельца (прокси Governance).
     */
    function transferOwnershipToGovernance(address governanceAddr) external onlyOwner {
        require(governanceAddr != address(0), "Governance address cannot be zero");
        transferOwnership(governanceAddr);
    }
}
