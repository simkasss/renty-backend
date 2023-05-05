// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

error TenantSoulboundToken__NotOwner();
error TenantSoulboundToken__CantBeTransferred();

contract TenantSoulboundToken is ERC721URIStorage {
    uint256 private s_tokenCounter;
    mapping(uint256 => address) private tokenIdToOwner;
    event SBTMinted(address minter, uint256 tokenId);

    constructor() ERC721("TenantSoulboundToken", "TSBT") {
        s_tokenCounter = 0;
    }

    //WHY THIS FUNCTION DOESNT WORK?
    function mintSBT(address owner, string memory tokenUri) public returns (uint256) {
        uint256 tokenId = s_tokenCounter;
        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, tokenUri);
        tokenIdToOwner[tokenId] = owner;
        emit SBTMinted(owner, tokenId);
        s_tokenCounter++;
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert TenantSoulboundToken__NotOwner();
        } // Only the owner of the token can burn it. This will send token to 0 address
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256, uint256) internal view override {
        if (from != address(0) && to != address(0)) {
            revert TenantSoulboundToken__CantBeTransferred();
        } // Soulbound token cannot be transferred, it can only be burned by the token owner.
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorage) {
        super._burn(tokenId);
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
