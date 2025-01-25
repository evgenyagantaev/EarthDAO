// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact eagantaev@gmail.com
contract EarthCitizenshipContract is ERC721, ERC721URIStorage, ERC721Burnable, Ownable 
{
    uint256 private _nextTokenId;
    string private _baseTokenURI;

    constructor() ERC721("EarthCitizenship", "GEC") Ownable(msg.sender) 
    {
        _nextTokenId = 0;
    }

    function setBaseURI(string memory newURI) external onlyOwner 
    {
        _baseTokenURI = newURI;
    }

    function safeMint() external 
    {
        require(balanceOf(msg.sender) == 0, "Address already has a citizenship token");
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _baseTokenURI);
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
