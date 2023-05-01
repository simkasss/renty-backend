/* This contract will handle management of rental agreements between property owners and tenants:
the creation, signing, storage, the payment of rent and the holding of security deposits in escrow.*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PropertyNft.sol";
import "./SoulboundToken.sol";

error RentApp__NotAdmin(address admin, address _admin);
error RentApp__NotOwner(address caller, uint256 tokenId)

contract RentApp {
    PropertyNft public propertyNFT;
    SoulboundToken public soulboundToken;
    address public nftContractAddress;
    address public soulboundContractAddress;
    address public constant admin;

    enum PropertyStatus {
        Rented,
        Vacant
    }
    enum ApplicationStatus {
        Waiting,
        Confirmed,
        Canceled
    }

    struct Property {
        uint256 id;
        address owner;
        string name;
        string description;
        string rentalTerm;
        uint256 rentPrice;
        uint256 amountOfDeposit;
        string hashOfRentalAggreement;
        PropertyStatus status;
    }
    struct Tenant {
        uint256 id;
        address tenant;
        string name;
        string[] history;
    }
    struct RentApplication {
        uint256 id;
        Property property;
        Tenant tenant;
        string rentalTerm;
        uint256 rentPrice;
        uint256 amountOfDeposit;
        string startDate;
        uint256 daysOfApplicationValidity;
        ApplicationStatus applicationStatus;
    }

    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfApplications;

    event PropertyListed(address indexed owner, uint256 indexed tokenId)
    event PropertyNFTminted(address indexed owner, uint256 indexed tokenId)
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId)
    event RentApplicationCreated(uint256 indexed _tenantTokenId, uint256 indexed applicationId)
    event RentApplicationConfirmed(uint256 indexed _propertyTokenId, uint256 indexed _applicationId)

    mapping(uint256 => address) private nftTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => address) private soulboundTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => Property) private tokenIdToProperty; //tokenId => Property
    mapping(uint256 => Tenant) private tokenIdToTenant; //tokenId => Tenant
    mapping(address => bool) private ownsTSBT;
    mapping(uint256 => RentApplication) private applicationIdToApplication;
    mapping(uint256 => RentApplication[]) private nftTokenIdToApplications;

    constructor(address propertyNftAddress, address soulboundTokenAddress) {
        nftContractAddress = propertyNftAddress;
        propertyNFT = PropertyNft(nftContractAddress);
        soulboundContractAddress = soulboundTokenAddress;
        soulboundToken = SoulboundToken(soulboundContractAddress);
        admin = msg.sender;
    }

    /* Main Functions
      1. Request for property's NFT (for owners)   HOW TO IMPLEMENT?
      2. Mint property's NFT (for admin) ✓
      3. Create SoulboundToken (for tenants) ✓
      4. List a property (for owners) ✓
      5. Create rent application (for tenants) ✓
      6. Accept rent application (for owners) ✓
      7. Transfer Security deposit (for tenants)
      8. Pay rent (for tenants)
      9. Withdraw rent (for owners)
      10. Terminate agreement (for owners or tenants)
      11. Request for renewal (for tenants)
      12. Update soulbound token (automatically)
      13. Release deposit (automatically)
      */
    modifier onlyAdmin() {
        if (admin != msg.sender) {
            revert RentApp__NotAdmin(admin, msg.sender);
        }
        _;
    }
    modifier onlyPropertyOwner(uint256 _tokenId) {
        if (msg.sender != nftTokenIdToOwner[_tokenId]) {
            revert RentApp__NotOwner(msg.sender, _tokenId);
        }
        _;
    }
    modifier onlyTSBTOwner(uint256 _tokenId) {
        if (msg.sender != soulboundTokenIdToOwner[_tokenId]) {
            revert RentApp__NotOwner(msg.sender, _tokenId);
        }
        _;
    }
    modifier onlyOneSBT(){
        if(ownsTSBT[msg.sender] == true){
            revert RentApp_AlreadyHasSBT(msg.sender);
        }
    }

    function mintPropertyNFT(address _owner, string memory _tokenUri) public onlyAdmin returns (uint256) {
       uint256 tokenId = propertyNFT.mintNft(_owner, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        nftTokenIdToOwner[tokenId] = _owner;
        emit PropertyNFTminted(_owner, tokenId);
        return tokenId;
    }

    function listProperty(string memory _name, string memory _description, uint256 _tokenId, string memory _rentalTerm, uint256 _rentPrice, uint256 _amountOfDeposit, string memory _hash) external onlyPropertyOwner(_tokenId)  {
        Property storage property = tokenIdToProperty[_tokenId];
        property.id = _tokenId;
        property.owner = msg.sender;
        property.name = _name;
        property.description = _description;
        property.rentalTerm = _rentalTerm;
        property.rentPrice = _rentPrice;
        property.amountOfDeposit = _amountOfDeposit;
        property.hashOfRentalAggreement = _hash;
        property.status = PropertyStatus.Vacant;
        numberOfProperties++;
        emit PropertyListed(msg.sender, _tokenId);
    }
    
    function mintSoulboundToken(string memory _name) external onlyOneSBT {
        uint256 tokenId = soulboundToken.safeMint(msg.sender); //This function should return tokenId
        //How can we get nftaddress?
        soulboundTokenIdToOwner[tokenId] = msg.sender;
        Tenant storage tenant = tokenIdToTenant[tokenId];
        tenant.id = tokenId;
        tenant.tenant = msg.sender;
        tenant.name = _name;
        tenant.history = [];
        numberOfTenants++;
        ownsTSBT[msg.sender] = true;
        emit SoulboundMinted(msg.sender, tokenId);
        return tokenId;
    }
    function createRentApplication(uint256 _nftTokenId, uint256 _tenantTokenId, string memory _rentalTerm, uint256 _rentPrice, uint256 _amountOfDeposit, string memory _startDate, uint256 _days ) external onlyTSBTOwner(_tenantTokenId) {
        uint256 applicationId = numberOfApplications;
        RentApplication storage rentApplication = applicationIdToApplication[applicationId]
        rentApplication.id = applicationId;
        rentApplication.property = tokenIdToProperty[_nftTokenId];
       rentApplication.tenant = tokenIdToTenant[_tenantTokenId];
        rentApplication.rentalTerm = _rentalTerm;
        rentApplication.rentPrice = _rentPrice;
        rentApplication.amountOfDeposit = _amountOfDeposit;
       rentApplication.startDate = _startDate;
        rentApplication.daysOfApplicationValidity = _days;
        rentApplication.applicationStatus = ApplicationStatus.Waiting;
        numberOfApplications++;
        emit RentApplicationCreated(_tenantTokenId, applicationId);
    }
    function acceptRentApplication(uint256 _propertyTokenId, uint256 _applicationId) external onlyPropertyOwner(_tokenId){
        applicationIdToApplication[_applicationId].applicationStatus = ApplicationStatus.Confirmed;
        tokenIdToProperty[_propertyTokenId].status = PropertyStatus.Rented;
        emit RentApplicationConfirmed(_tokenId, _applicationId);
    }


    }


