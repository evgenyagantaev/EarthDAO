// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _tokenIdCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _tokenIdCounter = 0;
    }

    function mint(address to, uint256 amount) external {
        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter++;
            _mint(to, _tokenIdCounter);
        }
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not owner nor approved");
        _burn(tokenId);
    }
} 