// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.22;

contract EarthStateMasterContract 
{
    // Contract registry: contract name => contract address
    mapping(string => address) public contracts;
    mapping(address => string) public contractNames;

    // Event that will be emitted when a contract is added
    event ContractAdded(string contractName, address contractAddress);
    // Event that will be emitted when a contract is removed
    event ContractRemoved(string contractName, address contractAddress);
    // Event that will be emitted when a contract is replaced
    event ContractReplaced(string contractName, address oldAddress, address newAddress);

    /**
     * @dev Adds a new contract to the registry.
     * Requires that the contract name is not empty and the contract address is not zero.
     * Requires that a contract with this name has not been registered yet.
     * @param _contractName Contract name for registration.
     * @param _contractAddress Contract address for registration.
     */
    function addContract(string memory _contractName, address _contractAddress) public 
    {
        require(bytes(_contractName).length > 0, "Contract name cannot be empty");
        require(_contractAddress != address(0), "Contract address cannot be zero");
        require(contracts[_contractName] == address(0), "Contract already registered with this name");

        contracts[_contractName] = _contractAddress;
        contractNames[_contractAddress] = _contractName;
        emit ContractAdded(_contractName, _contractAddress);
    }

    /**
     * @dev Removes a contract from the registry by name.
     * Requires that the contract with the specified name is registered.
     * @param _contractName Contract name to remove.
     */
    function removeContract(string memory _contractName) public 
    {
        require(bytes(_contractName).length > 0, "Contract name cannot be empty");
        require(contracts[_contractName] != address(0), "Contract not registered with this name");

        address contractAddress = contracts[_contractName]; // Save address before deletion for the event
        delete contracts[_contractName];
        delete contractNames[contractAddress];
        emit ContractRemoved(_contractName, contractAddress);
    }

    /**
     * @dev Replaces the address of an existing contract in the registry.
     * Requires that the contract name is not empty and the new contract address is not zero.
     * Requires that the contract with the specified name is registered.
     * @param _contractName Contract name to replace the address.
     * @param _newContractAddress New contract address.
     */
    function replaceContract(string memory _contractName, address _newContractAddress) public 
    {
        require(bytes(_contractName).length > 0, "Contract name cannot be empty");
        require(_newContractAddress != address(0), "New contract address cannot be zero");
        require(contracts[_contractName] != address(0), "Contract not registered with this name");

        address oldAddress = contracts[_contractName]; // Save old address for the event
        contracts[_contractName] = _newContractAddress;
        delete contractNames[oldAddress];
        contractNames[_newContractAddress] = _contractName;
        emit ContractReplaced(_contractName, oldAddress, _newContractAddress);
    }

    /**
     * @dev Returns the contract address by its name.
     * @param _contractName Contract name to look up.
     * @return address Contract address or zero address if contract is not found.
     */
    function getContractAddress(string memory _contractName) public view returns (address) 
    {
        return contracts[_contractName];
    }

    function getContractName(address _contractAddress) public view returns (string memory) 
    {
        return contractNames[_contractAddress];
    }
}

