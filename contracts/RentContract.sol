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
error RentApp__NotEnoughRentalPrice();
error RentApp__NoProceeds();
error RentApp__WithdrawFailed();

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
        uint256 rentalPrice;
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
        uint256 rentalPrice;
        uint256 amountOfDeposit;
        string startDate;
        uint256 daysOfApplicationValidity;
        TenantApplicationStatus applicationStatus;
    }

    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfApplications;

    event PropertyListed(address indexed owner, uint256 indexed tokenId)
     event PropertyUpdated(address indexed owner, uint256 indexed tokenId)
      event PropertyDeleted(address indexed owner, uint256 indexed tokenId)
    event PropertyNFTminted(address indexed owner, uint256 indexed tokenId)
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId)
    event RentApplicationCreated(uint256 indexed _tenantTokenId, uint256 indexed applicationId)
    event RentApplicationConfirmed(uint256 indexed _propertyTokenId, uint256 indexed _applicationId)
    event SecurityDepositTransfered(uint256 indexed propertyNftId, uint256 indexed rentApplicationId)
    event RentPriceTransfered(uint256 indexed propertyNftId, uint256 indexed rentApplicationId)

    mapping(uint256 => address) private nftTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => address) private soulboundTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => Property) private tokenIdToProperty; //tokenId => Property
    mapping(uint256 => Tenant) private tokenIdToTenant; //tokenId => Tenant
    mapping(address => bool) private ownsTSBT;
    mapping(uint256 => RentApplication) private applicationIdToApplication;
    mapping(uint256 => RentApplication[]) private nftTokenIdToApplications;

mapping(uint256 => uint256) private nftTokenIdToDeposit;
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
      5. Update a property (for owners) ✓
      5.1 Delete a property (for owners) ✓
      6. Create rent application (for tenants) ✓
      7. Accept rent application (for owners) ✓ // ALL OTHER APPLICATONS SHOULD BE CANCELED
      8. Transfer Security deposit (for tenants) ✓
      9. Pay rent (for tenants) ✓
      10. Withdraw rent (for owners) ✓
      11. Terminate agreement (for owners or tenants)
      12. Request for renewal (for tenants)
      13. Update soulbound token (automatically)
      14. Release deposit (automatically)

      */

     // didnt use it
    modifier onlyAdmin() {
        if (admin != msg.sender) {
            revert RentApp__NotAdmin(admin, msg.sender);
        }
        _;
    }
    modifier onlyPropertyOwner(uint256 _propertyNftId) {
        if (msg.sender != nftTokenIdToOwner[_propertyNftId]) {
            revert RentApp__NotOwner(msg.sender, _propertyNftId);
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

    function listProperty(string memory _name, string memory _description, uint256 _propertyNftId, string memory _rentalTerm, uint256 _rentalPrice, uint256 _amountOfDeposit, string memory _hash) external onlyPropertyOwner(_propertyNftId)  {
        Property storage property = tokenIdToProperty[_propertyNftId];
        property.propertyNftId = _propertyNftId;
        property.owner = msg.sender;
        property.name = _name;
        property.description = _description;
        property.rentalTerm = _rentalTerm;
        property.rentalPrice = _rentalPrice;
        property.amountOfDeposit = _amountOfDeposit;
        property.hashOfRentalAggreement = _hash;
        property.status = PropertyStatus.Vacant;
        numberOfProperties++;
        emit PropertyListed(msg.sender, _tokenId);
    }
    function updateProperty(string memory _name, string memory _description, uint256 _propertyNftId, string memory _rentalTerm, uint256 _rentPrice, uint256 _amountOfDeposit, string memory _hash) external onlyPropertyOwner(_propertyNftId)  {
         tokenIdToProperty[_tokenId].name = _name;
        tokenIdToProperty[_tokenId].description = _description;
         tokenIdToProperty[_tokenId].rentalTerm = _rentalTerm;
         tokenIdToProperty[_tokenId].rentPrice = _rentPrice;
         tokenIdToProperty[_tokenId].amountOfDeposit = _amountOfDeposit;
        tokenIdToProperty[_tokenId].hashOfRentalAggreement = _hash;
        emit PropertyUpdated(msg.sender, _tokenId);
    }
    function deleteProperty(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
delete (tokenIdToProperty[_propertyNftId])
emit PropertyDeleted(msg.sender, _propertyNftId);
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
    function createRentApplication(uint256 _nftTokenId, uint256 _tenantTokenId, string memory _rentalTerm, uint256 _rentalPrice, uint256 _amountOfDeposit, string memory _startDate, uint256 _days ) external onlyTSBTOwner(_tenantTokenId) {
        uint256 applicationId = numberOfApplications;
        RentApplication storage rentApplication = applicationIdToApplication[applicationId]
        rentApplication.rentApplicationId = applicationId;
        rentApplication.property = tokenIdToProperty[_nftTokenId];
       rentApplication.tenant = tokenIdToTenant[_tenantTokenId];
        rentApplication.rentalTerm = _rentalTerm;
        rentApplication.rentalPrice = _rentalPrice;
        rentApplication.amountOfDeposit = _amountOfDeposit;
       rentApplication.startDate = _startDate;
        rentApplication.daysOfApplicationValidity = _days; // How to write a code, that after these days status would change? chainlink keepers would cost
        rentApplication.applicationStatus = TenantApplicationStatus.Waiting;
        numberOfApplications++;
        emit RentApplicationCreated(_tenantTokenId, applicationId);
    }
    function acceptRentApplication(uint256 _propertyNftId, uint256 _rentApplicationId) external onlyPropertyOwner(_propertyNftId){
        applicationIdToApplication[_rentApplicationId].applicationStatus = TenantApplicationStatus.Confirmed;
        tokenIdToProperty[_propertyNftId].status = PropertyStatus.Rented;
        tokenIdToProperty[_propertyNftId].tenant = applicationIdToApplication[_rentApplicationId].tenant;
        emit RentApplicationConfirmed(_propertyNftId, _rentApplicationId);
    }  // ALL OTHER APPLICATONS SHOULD BE CANCELED
    // SECURITY DEPOSIT MUST BE TRANSFERED IN 5 DAYS AFTER CONFIRMATION, ELSE APPLICATION STATUS IS CANCELED
    // should I loop throw applicationIds and cancel them one by one?

    function transferSecurityDeposit(uint256 _propertyNftId, uint256 _rentApplicationId) external payable {
        if (applicationIdToApplication[_rentApplicationId].applicationStatus != TenantApplicationStatus.Confirmed || tokenIdToProperty[_propertyNftId].status != PropertyStatus.Rented) {
            revert RentApp__ApplicationNotConfirmed(_rentApplicationId);
        }
        if (msg.value < applicationIdToApplication[_rentApplicationId].amountOfDeposit) {
            revert RentApp__NotEnoughDeposit();
    }
    nftTokenIdToDeposit[_propertyNftId] = nftTokenIdToDeposit[_propertyNftId] + msg.value;
    emit SecurityDepositTransfered(_propertyNftId, _rentApplicationId);
    } 

    function transferRent(uint256 _propertyNftId, uint256 _rentApplicationId) external payable {
        if (applicationIdToApplication[_rentApplicationId].applicationStatus != TenantApplicationStatus.Confirmed || tokenIdToProperty[_propertyNftId].status != PropertyStatus.Rented) {
            revert RentApp__ApplicationNotConfirmed(_rentApplicationId);
        }
        if (msg.value < applicationIdToApplication[_rentApplicationId].rentalPrice) {
            revert RentApp__NotEnoughRentalPrice();
    }
    nftTokenIdToBalance[_propertyNftId] = nftTokenIdToBalance[_propertyNftId] + msg.value;
    emit RentPriceTransfered(_propertyNftId, _rentApplicationId);
    } // If the balance is not enough in the end of the month, a owner should be informed

    function withdrawProceeds(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
        uint256 proceeds = nftTokenIdToBalance[_propertyNftId];
        if(proceeds <= 0) {
            revert RentApp__NoProceeds();
        }
        nftTokenIdToBalance[_propertyNftId] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if(!success){
            revert RentApp__WithdrawFailed();
        }
    }

    }


