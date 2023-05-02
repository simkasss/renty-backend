// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error SoulboundToken__NotOwner();
error SoulboundToken__CantBeTransferred();

contract SoulboundToken is ERC721, Ownable {
    uint256 private s_tokenCounter;

    constructor() ERC721("TenantSoulboundToken", "TSBT") {}

    function safeMint(address to) public {
        uint256 tokenId = s_tokenCounter;
        s_tokenCounter++;
        _safeMint(to, tokenId);
        // Should include tokenUri which contains the name of a human being
    }

    function burn(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert SoulboundToken__NotOwner();
        } // Only the owner of the token can burn it. This will send token to 0 address
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256, uint256) internal pure override {
        if (from != address(0) || to != address(0)) {
            revert SoulboundToken__CantBeTransferred();
        } // Soulbound token cannot be transferred, it can only be burned by the token owner.
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }
}
