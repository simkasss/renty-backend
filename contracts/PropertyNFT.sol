//  This contract will allow to mint NFTs that represents properties.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract PropertyNft is ERC721URIStorage {
    string[] internal s_propertyTokenUris; //IPFS URI
    uint256 private s_tokenCounter;
    mapping(uint256 => address) private tokenIdToOwner;

    event NftMinted(address minter, uint256 tokenId);

    constructor() ERC721("Property NFT", "PROP") {
        s_tokenCounter = 0;
    }

    // get tokenURI("ipfs://") from IPFS
    function mintNft(address owner, string memory tokenUri) public returns (uint256) {
        uint256 tokenId = s_tokenCounter;
        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, tokenUri);
        tokenIdToOwner[tokenId] = owner;
        emit NftMinted(owner, tokenId);
        s_tokenCounter++;
        return tokenId;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getTokenOwner(uint256 tokenId) public view returns (address) {
        return tokenIdToOwner[tokenId];
    }
}
