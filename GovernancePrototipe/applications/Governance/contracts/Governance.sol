// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

/**
 * @title Governance
 * @dev Обновляемый (upgradeable) контракт для децентрализованного управления.
 *      Помимо стандартных функций голосования и апгрейда через UUPS,
 *      контракт хранит реестр (mapping) прокси‑контрактов с текстовыми именами.
 *      Функции управления реестром (добавить, удалить, заменить) доступны только через голосование,
 *      то есть их вызов производится самим Governance контрактом.
 */
contract Governance is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    // ===== Структура и переменные голосования =====
    struct Proposal {
        address target;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        uint256 snapshotBlock;
    }
    
    // Хранение предложений
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // Токен, используемый для голосования (например, ERC721Enumerable)
    IERC721EnumerableUpgradeable public votingToken;

    // Параметры голосования
    uint256 public voteWeightPerToken;
    uint256 public quorumPercentage; // например, 20 означает 20%
    uint256 public votingPeriod;     // период голосования в секундах

    // Фиксация факта голосования и срез голосов
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public snapshotVotingPower;

    // События голосования
    event ProposalCreated(uint256 indexed proposalId);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event GovernanceUpgraded(address indexed newImplementation);

    // ===== Реестр прокси‑контрактов =====
    // mapping текстового имени контракта (например, "OfficialCalendar") => адрес прокси
    mapping(string => address) public contractRegistry;

    // События реестра
    event RegistryContractAdded(string indexed name, address proxy);
    event RegistryContractRemoved(string indexed name, address proxy);
    event RegistryContractReplaced(string indexed name, address oldProxy, address newProxy);

    // ===== Модификаторы =====
    /**
     * @dev Доступно только если вызов инициирован самим Governance контрактом.
     *      Это гарантирует, что данные функции могут быть вызваны только через успешно выполненное голосование.
     */
    modifier onlyGovernance() {
        require(msg.sender == address(this), "Governance: Only governance can call");
        _;
    }

    // ===== Функция инициализации =====
    /**
     * @notice Инициализация контракта Governance.
     * @param _votingToken Адрес токена для голосования.
     * @param _voteWeightPerToken Вес голоса для каждого токена.
     * @param _quorumPercentage Минимальный процент голосов для кворума.
     * @param _votingPeriod Период голосования в секундах.
     */
    function initialize(
        address _votingToken,
        uint256 _voteWeightPerToken,
        uint256 _quorumPercentage,
        uint256 _votingPeriod
    ) public initializer {
        require(_votingToken != address(0), "Invalid token address");
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        votingToken = IERC721EnumerableUpgradeable(_votingToken);
        voteWeightPerToken = _voteWeightPerToken;
        quorumPercentage = _quorumPercentage;
        votingPeriod = _votingPeriod;
    }

    // ===== Функции голосования =====
    /**
     * @notice Создает новое предложение.
     * @param target Адрес контракта, вызов которого требуется выполнить.
     * @param data Данные для вызова target.
     * @return proposalId Идентификатор созданного предложения.
     */
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

    /**
     * @notice Голосует за или против предложения.
     * @param proposalId Идентификатор предложения.
     * @param support true — голос "за", false — "против".
     */
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 votingPower = snapshotVotingPower[proposalId][msg.sender];
        if (votingPower == 0) {
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

    /**
     * @notice Исполняет предложение, если выполнены условия кворума и большинство голосов "за".
     * @param proposalId Идентификатор предложения.
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 minQuorum = (votingToken.totalSupply() * voteWeightPerToken * quorumPercentage) / 100;
        require(totalVotes >= minQuorum, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal not passed");

        // Обновляем состояние до внешнего вызова (checks-effects-interactions)
        proposal.executed = true;
        
        // Выполняем вызов целевого контракта
        (bool success, ) = proposal.target.call(proposal.data);
        require(success, "Proposal execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Отменяет предложение. Отмену можно выполнить только через голосование.
     * @param proposalId Идентификатор предложения.
     */
    function cancelProposal(uint256 proposalId) external onlyGovernance {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");
        
        proposal.executed = true;
        emit ProposalCancelled(proposalId);
    }

    // ===== Функции апгрейда Governance =====
    /**
     * @notice Инициирует апгрейд контракта Governance через голосование.
     * @param newImplementation Адрес новой реализации.
     */
    function upgradeGovernance(address newImplementation) external onlyGovernance {
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
        emit GovernanceUpgraded(newImplementation);
    }

    /**
     * @dev Авторизация апгрейда (UUPS). Разрешено только через голосование.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {
        // Дополнительные проверки можно добавить здесь.
    }

    // ===== Функции управления реестром прокси‑контрактов =====
    /**
     * @notice Добавляет новый адрес прокси в реестр.
     * @param name Текстовое имя контракта.
     * @param proxy Адрес прокси‑контракта.
     */
    function addContractToRegistry(string memory name, address proxy) external onlyGovernance {
        require(proxy != address(0), "Invalid proxy address");
        require(contractRegistry[name] == address(0), "Contract already registered");
        contractRegistry[name] = proxy;
        emit RegistryContractAdded(name, proxy);
    }

    /**
     * @notice Удаляет адрес прокси из реестра по имени.
     * @param name Текстовое имя контракта.
     */
    function removeContractFromRegistry(string memory name) external onlyGovernance {
        require(contractRegistry[name] != address(0), "Contract not registered");
        address removedProxy = contractRegistry[name];
        delete contractRegistry[name];
        emit RegistryContractRemoved(name, removedProxy);
    }

    /**
     * @notice Заменяет адрес прокси для данного имени.
     * @param name Текстовое имя контракта.
     * @param newProxy Новый адрес прокси‑контракта.
     */
    function replaceContractInRegistry(string memory name, address newProxy) external onlyGovernance {
        require(newProxy != address(0), "Invalid proxy address");
        require(contractRegistry[name] != address(0), "Contract not registered");
        address oldProxy = contractRegistry[name];
        contractRegistry[name] = newProxy;
        emit RegistryContractReplaced(name, oldProxy, newProxy);
    }
}
