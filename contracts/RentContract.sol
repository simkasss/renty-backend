/* This contract will handle management of rental agreements between property owners and tenants:
the creation, signing, storage, the payment of rent and the holding of security deposits in escrow.*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PropertyNft.sol";
import "./SoulboundToken.sol";

error RentApp__NotAdmin(address admin, address _admin);
error RentApp__NotOwner(address caller, uint256 tokenId);
error RentApp__ApplicationNotConfirmed(uint256 rentApplicationId);
error RentApp__NotEnoughDeposit();

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
    enum TenantApplicationStatus {
        Waiting,
        Confirmed,
        Canceled
    }

    struct Property {
        uint256 propertyNftId;
        address owner;
        string name;
        string description;
        string rentalTerm;
        uint256 rentPrice;
        uint256 amountOfDeposit;
        string hashOfRentalAggreement;
        PropertyStatus status;
        Tenant tenant;
    }
    struct Tenant {
        uint256 sbtId; //address lives on the SBT
        string name;
        RentApplication[] rentHistory;
    }
    struct RentApplication {
        uint256 rentApplicationId;
        Property property;
        Tenant tenant;
        string rentalTerm;
        uint256 rentPrice;
        uint256 amountOfDeposit;
        string startDate;
        uint256 daysOfApplicationValidity;
        TenantApplicationStatus applicationStatus;
    }

    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfApplications;

    event PropertyListed(address indexed owner, uint256 indexed tokenId)
    event PropertyNFTminted(address indexed owner, uint256 indexed tokenId)
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId)
    event RentApplicationCreated(uint256 indexed _tenantTokenId, uint256 indexed applicationId)
    event RentApplicationConfirmed(uint256 indexed _propertyTokenId, uint256 indexed _applicationId)
    event SecurityDepositTransfered(uint256 indexed propertyNftId, uint256 indexed rentApplicationId)

    mapping(uint256 => address) private nftTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => address) private soulboundTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => Property) private tokenIdToProperty; //tokenId => Property
    mapping(uint256 => Tenant) private tokenIdToTenant; //tokenId => Tenant
    mapping(address => bool) private ownsTSBT;
    mapping(uint256 => RentApplication) private applicationIdToApplication;
    mapping(uint256 => RentApplication[]) private nftTokenIdToApplications;

    mapping(uint256 => uint256) private nftTokenIdToBalance;

    constructor(address propertyNftAddress, address soulboundTokenAddress) {
        nftContractAddress = propertyNftAddress;
        propertyNFT = PropertyNft(nftContractAddress);
        soulboundContractAddress = soulboundTokenAddress;
        soulboundToken = SoulboundToken(soulboundContractAddress);
        admin = msg.sender;
    }

    /* Main Functions
      1. Request for property's NFT (for owners)   HOW TO IMPLEMENT?
      2. Mint property's NFT  ✓
      3. Create SoulboundToken (for tenants) ✓
      4. List a property (for owners) ✓
      5. Create rent application (for tenants) ✓
      6. Accept rent application (for owners) ✓ // ALL OTHER APPLICATONS SHOULD BE CANCELED
      7. Transfer Security deposit (for tenants)
      8. Pay rent (for tenants)
      9. Withdraw rent (for owners)
      10. Terminate agreement (for owners or tenants)
      11. Request for renewal (for tenants)
      12. Update soulbound token (automatically)
      13. Release deposit (automatically)
      */

     // didnt use it
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

    function mintPropertyNFT(string memory _tokenUri) public returns (uint256) {
       uint256 tokenId = propertyNFT.mintNft(msg.sender, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        nftTokenIdToOwner[tokenId] = msg.sender;
        emit PropertyNFTminted(msg.sender, tokenId);
        return tokenId;
    }

    function listProperty(string memory _name, string memory _description, uint256 _tokenId, string memory _rentalTerm, uint256 _rentPrice, uint256 _amountOfDeposit, string memory _hash) external onlyPropertyOwner(_tokenId)  {
        Property storage property = tokenIdToProperty[_tokenId];
        property.propertyNftId = _tokenId;
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
    
    function mintSoulboundToken(string memory _name, string memory _tokenUri) external onlyOneSBT {
        uint256 tokenId = soulboundToken.mintSBT(msg.sender, _tokenUri) ; //This function should return tokenId
        //How can we get nftaddress?
        soulboundTokenIdToOwner[tokenId] = msg.sender;
        Tenant storage tenant = tokenIdToTenant[tokenId];
        tenant.sbtId = tokenId;
        tenant.name = _name;
        tenant.rentHistory = [];
        numberOfTenants++;
        ownsTSBT[msg.sender] = true;
        emit SoulboundMinted(msg.sender, tokenId);
        return tokenId;
    }
    function createRentApplication(uint256 _nftTokenId, uint256 _tenantTokenId, string memory _rentalTerm, uint256 _rentPrice, uint256 _amountOfDeposit, string memory _startDate, uint256 _days ) external onlyTSBTOwner(_tenantTokenId) {
        uint256 applicationId = numberOfApplications;
        RentApplication storage rentApplication = applicationIdToApplication[applicationId]
        rentApplication.rentApplicationId = applicationId;
        rentApplication.property = tokenIdToProperty[_nftTokenId];
       rentApplication.tenant = tokenIdToTenant[_tenantTokenId];
        rentApplication.rentalTerm = _rentalTerm;
        rentApplication.rentPrice = _rentPrice;
        rentApplication.amountOfDeposit = _amountOfDeposit;
       rentApplication.startDate = _startDate;
        rentApplication.daysOfApplicationValidity = _days; // How to write a code, that after these days status would change? chainlink keepers would cost
        rentApplication.applicationStatus = TenantApplicationStatus.Waiting;
        numberOfApplications++;
        emit RentApplicationCreated(_tenantTokenId, applicationId);
    }
    function acceptRentApplication(uint256 _propertyNftId, uint256 _rentApplicationId) external onlyPropertyOwner(_tokenId){
        applicationIdToApplication[_rentApplicationId].applicationStatus = TenantApplicationStatus.Confirmed;
        tokenIdToProperty[_propertyNftId].status = PropertyStatus.Rented;
        tokenIdToProperty[_propertyNftId].tenant = applicationIdToApplication[_rentApplicationId].tenant;
        emit RentApplicationConfirmed(_propertyNftId, _rentApplicationId);
    }  // ALL OTHER APPLICATONS SHOULD BE CANCELED
    // should I loop throw applicationIds and cancel them one by one?

    function transferSecurityDeposit(uint256 _propertyNftId, uint256 _rentApplicationId) external payable {
        if (applicationIdToApplication[_rentApplicationId].applicationStatus != TenantApplicationStatus.Confirmed || tokenIdToProperty[_propertyNftId].status != PropertyStatus.Rented) {
            revert RentApp__ApplicationNotConfirmed(_rentApplicationId);
        }
        if (msg.value < applicationIdToApplication[_rentApplicationId].amountOfDeposit) {
            revert RentApp__NotEnoughDeposit();
    }
    nftTokenIdToBalance[_propertyNftId] = nftTokenIdToBalance[_propertyNftId] + msg.value;
    emit SecurityDepositTransfered(_propertyNftId, _rentApplicationId);



    }
    }


