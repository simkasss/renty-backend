/* This contract will handle management of rental agreements between property owners and tenants:
the creation, signing, storage, the payment of rent and the holding of security deposits in escrow.*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PropertyNFT.sol";
import "./TenantSoulboundToken.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

error RentApp__NotAdmin(address admin, address _admin);
error RentApp__NotOwner(address caller, uint256 tokenId);
error RentApp__ContractNotConfirmed(uint256 rentContractId);
error RentApp__NotEnoughDeposit();
error RentApp__NotEnoughRentalPrice();
error RentApp__NoProceeds();
error RentApp__WithdrawFailed();
error RentApp__TerminationFailed(address caller, uint256 propertyNftId);
error RentApp__InvalidRentContract();
error RentApp__PropertyIsNotListed();
error RentApp__AlreadyHasSBT(address caller);

contract RentApp {
    PropertyNft public propertyNFT;
    TenantSoulboundToken public tenantSoulboundToken;
    address public propertyNftContractAddress;
    address public tenantSoulboundContractAddress;
    using EnumerableSet for EnumerableSet.UintSet;

    enum RentContractStatus {
        Waiting,
        Confirmed,
        Canceled
    }
    struct RentContract {
        uint256 id;
        uint256 propertyNftId;
        Tenant tenant;
        string rentalTerm;
        uint256 rentalPrice;
        uint256 depositAmount;
        string startDate;
        uint256 daysOfApplicationValidity; // should we use it?
        RentContractStatus status;
        uint256 propertyRentContractsAccepted;
    }

    struct Property {
        uint256 propertyNftId;
        address owner;
        string name;
        string description;
        string rentalTerm;
        uint256 rentalPrice;
        uint256 depositAmount;
        string hashOfRentalAggreement;
        uint256 rentContractsAccepted;
        RentContract rentContract; // if a Property has RentContract it is rented, if not it is vacant.
    }
    struct Tenant {
        uint256 sbtId; //address lives on the SBT
        string name;
        RentContract[] rentHistory;
    }

    event PropertyListed(address indexed owner, uint256 indexed tokenId);
    event PropertyUpdated(address indexed owner, uint256 indexed tokenId);
    event PropertyRemovedFromList(address indexed owner, uint256 indexed tokenId);
    event PropertyNFTminted(address indexed owner, uint256 indexed tokenId);
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId);
    event RentContractCreated(uint256 indexed tenantTokenId, uint256 indexed rentContractId);
    event RentContractConfirmed(uint256 indexed propertyTokenId, uint256 indexed rentContractId);
    event SecurityDepositTransfered(uint256 indexed propertyNftId, uint256 indexed rentContractIdd);
    event RentPriceTransfered(uint256 indexed propertyNftId, uint256 indexed rentContractId);

    EnumerableSet.UintSet private listedProperties;
    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfContracts;

    mapping(uint256 => address) private nftTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => address) private soulboundTokenIdToOwner; //tokenId => Owner
    mapping(uint256 => Property) private tokenIdToProperty; //tokenId => Property
    mapping(uint256 => Tenant) private tokenIdToTenant; //tokenId => Tenant
    mapping(address => bool) private ownsTSBT;
    mapping(uint256 => RentContract) private rentContractIdToRentContract;
    mapping(uint256 => RentContract[]) private nftTokenIdToContracts;
    mapping(uint256 => uint256) private nftTokenIdToDeposit;
    mapping(uint256 => uint256) private nftTokenIdToBalance;
    mapping(uint256 => bool) private rentContractHasDisputes;

    constructor(address _propertyNftContractAddress, address _tenantSoulboundContractAddress) {
        propertyNftContractAddress = _propertyNftContractAddress;
        propertyNFT = PropertyNft(propertyNftContractAddress);
        tenantSoulboundContractAddress = _tenantSoulboundContractAddress;
        tenantSoulboundToken = TenantSoulboundToken(tenantSoulboundContractAddress);
    }

    /* Main Functions
      1. Request for property's NFT (for owners)   HOW TO IMPLEMENT?
      2. Mint property's NFT  ✓
      3. Create SoulboundToken (for tenants) ✓
      4. List a property (for owners) ✓
      5. Update a property (for owners) ✓
      5.1 Delete a property from a list (for owners) ✓
      6. Create rent contract (for tenants) ✓
      7. Accept rent contract (for owners) ✓ // ALL OTHER APPLICATONS SHOULD BE CANCELED
        // Rental agreement is valid for a year from a start date (if not renewed)
      8. Transfer Security deposit (for tenants) ✓
      9. Pay rent (for tenants) ✓
      10. Withdraw rent (for owners) ✓
      11. Terminate agreement (for owners or tenants) // dispute is created 
      12. Request for renewal (for tenants)
      13. Update soulbound token (automatically)
      14. Create dispute (for owners or tenants) 
      15. Close dispute (for owners or tenants) // both have to call this func. to close a dispute
      16. Release deposit (automatically)
      17. Cancel RentContract (if it is not signed)

      */

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
    modifier onlyOneSBT() {
        if (ownsTSBT[msg.sender] == true) {
            revert RentApp__AlreadyHasSBT(msg.sender);
        }
        _;
    }

    function mintPropertyNFT(string memory _tokenUri) public returns (uint256) {
        uint256 tokenId = propertyNFT.mintNft(msg.sender, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        nftTokenIdToOwner[tokenId] = msg.sender;
        emit PropertyNFTminted(msg.sender, tokenId);
        return tokenId;
    }

    function listProperty(
        string memory _name,
        string memory _description,
        uint256 _propertyNftId,
        string memory _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        string memory _hash
    ) external onlyPropertyOwner(_propertyNftId) {
        Property storage property = tokenIdToProperty[_propertyNftId];
        property.propertyNftId = _propertyNftId;
        property.owner = msg.sender;
        property.name = _name;
        property.description = _description;
        property.rentalTerm = _rentalTerm;
        property.rentalPrice = _rentalPrice;
        property.depositAmount = _depositAmount;
        property.hashOfRentalAggreement = _hash;
        property.rentContractsAccepted = 0;
        numberOfProperties++;
        listedProperties.add(_propertyNftId);
        emit PropertyListed(msg.sender, _propertyNftId);
    }

    function updateProperty(
        string memory _name,
        string memory _description,
        uint256 _propertyNftId,
        string memory _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        string memory _hash
    ) external onlyPropertyOwner(_propertyNftId) {
        tokenIdToProperty[_propertyNftId].name = _name;
        tokenIdToProperty[_propertyNftId].description = _description;
        tokenIdToProperty[_propertyNftId].rentalTerm = _rentalTerm;
        tokenIdToProperty[_propertyNftId].rentalPrice = _rentalPrice;
        tokenIdToProperty[_propertyNftId].depositAmount = _depositAmount;
        tokenIdToProperty[_propertyNftId].hashOfRentalAggreement = _hash;
        emit PropertyUpdated(msg.sender, _propertyNftId);
    }

    function removePropertyFromList(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
        listedProperties.remove(_propertyNftId);
        emit PropertyRemovedFromList(msg.sender, _propertyNftId); //dont delete a property
    }

    function mintSoulboundToken(string memory _name, string memory _tokenUri) external onlyOneSBT returns (uint256) {
        uint256 tokenId = tenantSoulboundToken.mintSBT(msg.sender, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        soulboundTokenIdToOwner[tokenId] = msg.sender;
        Tenant storage tenant = tokenIdToTenant[tokenId];
        tenant.sbtId = tokenId;
        tenant.name = _name;
        numberOfTenants++;
        ownsTSBT[msg.sender] = true;
        emit SoulboundMinted(msg.sender, tokenId);
        return tokenId;
    }

    function createRentContract(
        uint256 _propertyNftId,
        uint256 _tenantTokenId,
        string memory _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        string memory _startDate,
        uint256 _days
    ) external onlyTSBTOwner(_tenantTokenId) {
        if (!listedProperties.contains(_propertyNftId)) {
            revert RentApp__PropertyIsNotListed();
        }
        uint256 rentContractId = numberOfContracts;
        RentContract storage rentContract = rentContractIdToRentContract[rentContractId];
        rentContract.id = rentContractId;
        rentContract.propertyNftId = tokenIdToProperty[_propertyNftId].propertyNftId;
        rentContract.tenant = tokenIdToTenant[_tenantTokenId];
        rentContract.rentalTerm = _rentalTerm;
        rentContract.rentalPrice = _rentalPrice;
        rentContract.depositAmount = _depositAmount;
        rentContract.startDate = _startDate;
        rentContract.daysOfApplicationValidity = _days; // How to write a code, that after these days status would change? chainlink keepers would cost
        rentContract.status = RentContractStatus.Waiting;
        rentContract.propertyRentContractsAccepted = tokenIdToProperty[_propertyNftId].rentContractsAccepted;
        numberOfContracts++;
        nftTokenIdToContracts[_propertyNftId].push(rentContract);
        emit RentContractCreated(_tenantTokenId, rentContractId);
    }

    function acceptRentContract(uint256 _propertyNftId, uint256 _rentContractId) external onlyPropertyOwner(_propertyNftId) {
        if (
            tokenIdToProperty[_propertyNftId].rentContractsAccepted != rentContractIdToRentContract[_rentContractId].propertyRentContractsAccepted ||
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Waiting
        ) {
            revert RentApp__InvalidRentContract();
        }
        tokenIdToProperty[_propertyNftId].rentContractsAccepted++;
        rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Confirmed;
        tokenIdToProperty[_propertyNftId].rentContract = rentContractIdToRentContract[_rentContractId];
        emit RentContractConfirmed(_propertyNftId, _rentContractId);
    } // ALL OTHER APPLICATONS SHOULD BE CANCELED, SHOW THIS IN UI

    // SECURITY DEPOSIT MUST BE TRANSFERED IN 5 DAYS AFTER CONFIRMATION, ELSE CONTRACT STATUS IS CANCELED

    function transferSecurityDeposit(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        if (
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Confirmed ||
            rentContractIdToRentContract[_rentContractId].propertyNftId != tokenIdToProperty[_propertyNftId].propertyNftId
        ) {
            revert RentApp__ContractNotConfirmed(_rentContractId);
        }
        if (msg.value < rentContractIdToRentContract[_rentContractId].depositAmount) {
            revert RentApp__NotEnoughDeposit();
        }
        nftTokenIdToDeposit[_propertyNftId] = nftTokenIdToDeposit[_propertyNftId] + msg.value;
        emit SecurityDepositTransfered(_propertyNftId, _rentContractId);
    }

    function transferRent(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        if (
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Confirmed ||
            rentContractIdToRentContract[_rentContractId].propertyNftId != tokenIdToProperty[_propertyNftId].propertyNftId
        ) {
            revert RentApp__ContractNotConfirmed(_rentContractId);
        }
        if (msg.value < rentContractIdToRentContract[_rentContractId].rentalPrice) {
            revert RentApp__NotEnoughRentalPrice();
        }
        nftTokenIdToBalance[_propertyNftId] = nftTokenIdToBalance[_propertyNftId] + msg.value;
        emit RentPriceTransfered(_propertyNftId, _rentContractId);
    } // If the balance is not enough in the end of the month, a owner should be informed

    function withdrawProceeds(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
        uint256 proceeds = nftTokenIdToBalance[_propertyNftId];
        if (proceeds <= 0) {
            revert RentApp__NoProceeds();
        }
        nftTokenIdToBalance[_propertyNftId] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert RentApp__WithdrawFailed();
        }
    }

    function terminateAgreement(uint256 _propertyNftId, uint256 _tenantTokenId, uint256 _rentContractId) external {
        if (msg.sender == nftTokenIdToOwner[_propertyNftId] || msg.sender == soulboundTokenIdToOwner[_tenantTokenId]) {
            if (_tenantTokenId == rentContractIdToRentContract[_rentContractId].tenant.sbtId) {
                rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Canceled;
                delete tokenIdToProperty[_propertyNftId].rentContract;
                rentContractHasDisputes[_rentContractId] = true; // automatically create a dispute
                // implementation of tenant rent history update:
                tokenIdToTenant[_tenantTokenId].rentHistory.push(rentContractIdToRentContract[_rentContractId]);
                //should I add ,,ended with unclosed dispute" to contract properties?
            }
        } else {
            revert RentApp__TerminationFailed(msg.sender, _propertyNftId);
        }
    }

    // Getters
    function getListedProperties() public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](listedProperties.length());
        for (uint256 i = 0; i < listedProperties.length(); i++) {
            ids[i] = listedProperties.at(i);
        }
        return ids;
    } // It looks expensive
}
