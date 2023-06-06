// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./MainContract.sol";

error TenantManager__NotOwner();
error TenantManager__CantBeTransfered();
error TenantManager__AlreadyHasSBT(address caller);
error TenantManager__DoesntHaveSBT(address owner);

contract TenantManager is ERC721URIStorage {
    uint256 private s_tokenCounter;
    mapping(uint256 => address) private tokenIdToOwner;
    mapping(address => uint256) private ownerToTokenId;
    mapping(uint256 => string) private tokenIdToName;
    mapping(address => bool) public ownsTSBT;

    event SoulboundMinted(address owner, uint256 tokenId);

    constructor() ERC721("TenantSoulboundToken", "TSBT") {
        s_tokenCounter = 0;
    }

    function mintSBT(string memory tokenUri, string memory name) public returns (uint256) {
        if (ownsTSBT[msg.sender] == true) {
            revert TenantManager__AlreadyHasSBT(msg.sender);
        }
        uint256 tokenId = s_tokenCounter;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenUri);
        tokenIdToOwner[tokenId] = msg.sender;
        tokenIdToName[tokenId] = name;
        ownsTSBT[msg.sender] = true;
        ownerToTokenId[msg.sender] = tokenId;

        emit SoulboundMinted(msg.sender, tokenId);
        s_tokenCounter++;
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        if (tokenIdToOwner[tokenId] != msg.sender) {
            revert TenantManager__NotOwner();
        } // Only the owner of the token can burn it. This will send token to 0 address
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256, uint256) internal pure override {
        if (from != address(0) && to != address(0)) {
            revert TenantManager__CantBeTransfered();
        } // Soulbound token cannot be transferred, it can only be burned by the token owner.
    }

    function _burn(uint256 tokenId) internal override(ERC721URIStorage) {
        super._burn(tokenId);
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getTokenOwner(uint256 tokenId) public view returns (address) {
        return tokenIdToOwner[tokenId];
    }

    function getTokenId(address owner) public view returns (uint256) {
        if (!ownsTSBT[owner]) {
            revert TenantManager__DoesntHaveSBT(owner);
        }
        return ownerToTokenId[owner];
    }

    function getTokenOwnerName(uint256 tokenId) public view returns (string memory) {
        return tokenIdToName[tokenId];
    }
}
