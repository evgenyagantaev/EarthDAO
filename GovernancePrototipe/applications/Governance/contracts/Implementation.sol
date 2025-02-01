// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./StorageLayout.sol";

contract Implementation is Initializable, StorageLayout {
    event Initialized(address governanceContract, address votingToken);

    modifier onlyGovernance() {
        require(msg.sender == governanceContract, "Only governance can call this function");
        _;
    }

    modifier onlyTokenHolder() {
        require(votingToken.balanceOf(msg.sender) > 0, "Must own voting token");
        _;
    }

    function initialize(address _governanceContract) external initializer {
        require(_governanceContract != address(0), "Invalid governance address");
        
        governanceContract = _governanceContract;
        votingToken = IERC721(IGovernance(_governanceContract).votingToken());
        version = 1;

        emit Initialized(_governanceContract, address(votingToken));
    }

    // Общая утилитарная функция - доступна всем держателям токенов
    function utilityFunction() external onlyTokenHolder {
        // Общая логика
    }

    // Функция обновления только для governance
    function upgradeFunction() external onlyGovernance {
        // Логика обновления
    }
}

interface IGovernance {
    function votingToken() external view returns (address);
} 