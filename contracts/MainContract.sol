/* This contract will handle management of rental agreements between property owners and tenants:
the creation, signing, storage, the payment of rent and the holding of security deposits in escrow.*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./PropertyNFT.sol";
import "./TenantManager.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error MainContract__NotOwner(address caller, uint256 tokenId);
error MainContract__InvalidRentContract();
error MainContract__CancelFailed(address caller, uint256 propertyNftId);
error MainContract__PropertyIsNotListed();
error MainContract__OwnerCantBeTenant();
error MainContract__DoesntHaveSBT(address user);
error MainContract__AllowDepositReleaseFailed(address owner, uint256 rentContractId);
error MainContract__DoesntHaveCurrentContract();

contract MainContract {
    PropertyNft public propertyNFT;
    TenantManager public tenantManager;

    AggregatorV3Interface private priceFeed;
    address private propertyNftContractAddress;
    address private tenantManagerAddress;

    using EnumerableSet for EnumerableSet.UintSet;

    enum RentContractStatus {
        Waiting,
        Confirmed,
        Canceled
    }

    struct RentContract {
        uint256 id;
        uint256 propertyNftId;
        uint256 tenantSbtId;
        uint256 rentalTerm; //in seconds
        uint256 rentalPrice;
        uint256 depositAmount;
        uint256 startTimestamp;
        uint256 validityTerm;
        RentContractStatus status;
        uint256 expiryTimestamp;
        uint256 propertyRentContractsAccepted;
    }

    struct Property {
        uint256 propertyNftId;
        string name;
        string description;
        uint256 rentalTerm;
        uint256 rentalPrice;
        uint256 depositAmount;
        string hashOfTermsAndConditions;
        string hashOfPropertyMetaData;
        string[] hashesOfPhotos;
        uint256 rentContractsAccepted;
        bool isRented;
        uint256 rentContractId;
    }
    event PropertyCreated(address indexed owner, uint256 indexed propertyId);
    event PropertyListed(address indexed owner, uint256 indexed tokenId);
    event PropertyRemovedFromList(address indexed owner, uint256 indexed tokenId);
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId);
    event RentContractCreated(uint256 indexed tenantTokenId, uint256 indexed rentContractId);
    event RentContractConfirmed(uint256 indexed propertyTokenId, uint256 indexed rentContractId);

    EnumerableSet.UintSet private listedProperties;
    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfContracts;

    mapping(uint256 => address) public nftTokenIdToOwner;
    mapping(address => uint256[]) public ownerToNftTokenIds;
    mapping(uint256 => Property) public tokenIdToProperty;
    mapping(address => bool) public ownsTSBT;
    mapping(uint256 => RentContract) public rentContractIdToRentContract;
    mapping(uint256 => uint256[]) public nftTokenIdToContractsIds;
    mapping(uint256 => uint256[]) public sbtIdToContractsIds;
    mapping(uint256 => uint256[]) sbtTokenIdToRentHistoryIds;
    mapping(uint256 => uint256[]) propertyIdToRentHistoryIds;
    mapping(uint256 => uint256) tenantCurrentContractId;
    mapping(address => string) addressToEmail;
    mapping(address => string) addressToPhoneNumber;

    constructor(address _propertyNftContractAddress, address _tenantManagerAddress, address _priceFeedAddress) {
        propertyNftContractAddress = _propertyNftContractAddress;
        propertyNFT = PropertyNft(propertyNftContractAddress);

        tenantManagerAddress = _tenantManagerAddress;
        tenantManager = TenantManager(tenantManagerAddress);
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    modifier onlyPropertyOwner(uint256 _propertyNftId) {
        if (msg.sender != nftTokenIdToOwner[_propertyNftId]) {
            revert MainContract__NotOwner(msg.sender, _propertyNftId);
        }
        _;
    }

    function createProperty(string memory _tokenUri, string memory _name, string memory _hashOfPropertyMetaData) public returns (uint256) {
        uint256 propertyId = propertyNFT.mintNft(msg.sender, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        nftTokenIdToOwner[propertyId] = msg.sender;
        ownerToNftTokenIds[msg.sender].push(propertyId);
        Property storage property = tokenIdToProperty[propertyId];
        property.name = _name;
        property.hashOfPropertyMetaData = _hashOfPropertyMetaData;
        property.propertyNftId = propertyId;
        property.rentContractsAccepted = 0;
        property.isRented = false;
        numberOfProperties++;
        emit PropertyCreated(msg.sender, propertyId);
        return propertyId;
    }

    function listProperty(
        string memory _description,
        uint256 _propertyNftId,
        uint256 _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        string[] memory _hashesOfPhotos,
        string memory _hashOfTermsAndConditions
    ) external onlyPropertyOwner(_propertyNftId) {
        Property storage property = tokenIdToProperty[_propertyNftId];
        property.description = _description;
        property.rentalTerm = _rentalTerm;
        property.rentalPrice = _rentalPrice;
        property.depositAmount = _depositAmount;
        property.hashesOfPhotos = _hashesOfPhotos;
        property.hashOfTermsAndConditions = _hashOfTermsAndConditions;
        listedProperties.add(_propertyNftId);
        emit PropertyListed(msg.sender, _propertyNftId);
    }

    function updateProperty(
        string memory _name,
        string memory _description,
        uint256 _propertyNftId,
        uint256 _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        string[] memory _hashesOfPhotos,
        string memory _hashOfTermsAndConditions
    ) external onlyPropertyOwner(_propertyNftId) {
        tokenIdToProperty[_propertyNftId].name = _name;
        tokenIdToProperty[_propertyNftId].description = _description;
        tokenIdToProperty[_propertyNftId].rentalTerm = _rentalTerm;
        tokenIdToProperty[_propertyNftId].rentalPrice = _rentalPrice;
        tokenIdToProperty[_propertyNftId].depositAmount = _depositAmount;
        tokenIdToProperty[_propertyNftId].hashesOfPhotos = _hashesOfPhotos;
        tokenIdToProperty[_propertyNftId].hashOfTermsAndConditions = _hashOfTermsAndConditions;
    }

    function removePropertyFromList(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
        listedProperties.remove(_propertyNftId);
        emit PropertyRemovedFromList(msg.sender, _propertyNftId); //dont delete a property
    }

    function addContactDetails(string memory _email, string memory _phoneNumber) external {
        addressToEmail[msg.sender] = _email;
        addressToPhoneNumber[msg.sender] = _phoneNumber;
    }

    function createRentContract(
        uint256 _propertyNftId,
        uint256 _tenantTokenId,
        uint256 _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        uint256 _startTimestamp,
        uint256 _validityTerm
    ) external {
        address tenant = tenantManager.getTokenOwner(_tenantTokenId);
        if (!listedProperties.contains(_propertyNftId)) {
            revert MainContract__PropertyIsNotListed();
        }
        if (tenant == nftTokenIdToOwner[_propertyNftId]) {
            revert MainContract__OwnerCantBeTenant();
        }
        if (msg.sender != tenant) {
            revert MainContract__NotOwner(msg.sender, _tenantTokenId);
        }
        numberOfContracts++;
        uint256 rentContractId = numberOfContracts;
        RentContract storage rentContract = rentContractIdToRentContract[rentContractId];
        rentContract.id = rentContractId;
        rentContract.propertyNftId = tokenIdToProperty[_propertyNftId].propertyNftId;
        rentContract.tenantSbtId = _tenantTokenId;
        rentContract.rentalTerm = _rentalTerm;
        rentContract.rentalPrice = _rentalPrice;
        rentContract.depositAmount = _depositAmount;
        rentContract.startTimestamp = _startTimestamp;
        rentContract.validityTerm = _validityTerm;
        rentContract.status = RentContractStatus.Waiting;
        rentContract.propertyRentContractsAccepted = tokenIdToProperty[_propertyNftId].rentContractsAccepted;
        nftTokenIdToContractsIds[_propertyNftId].push(rentContractId);
        sbtIdToContractsIds[_tenantTokenId].push(rentContractId);

        emit RentContractCreated(_tenantTokenId, rentContractId);
    }

    function acceptRentContract(uint256 _propertyNftId, uint256 _rentContractId) external onlyPropertyOwner(_propertyNftId) {
        if (
            tokenIdToProperty[_propertyNftId].rentContractsAccepted != rentContractIdToRentContract[_rentContractId].propertyRentContractsAccepted ||
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Waiting ||
            rentContractIdToRentContract[_rentContractId].validityTerm < block.timestamp
        ) {
            revert MainContract__InvalidRentContract();
        }
        tokenIdToProperty[_propertyNftId].rentContractsAccepted++;
        rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Confirmed;
        tokenIdToProperty[_propertyNftId].rentContractId = rentContractIdToRentContract[_rentContractId].id;

        tokenIdToProperty[_propertyNftId].isRented = true;
        rentContractIdToRentContract[_rentContractId].expiryTimestamp =
            rentContractIdToRentContract[_rentContractId].startTimestamp +
            rentContractIdToRentContract[_rentContractId].rentalTerm;
        tenantCurrentContractId[rentContractIdToRentContract[_rentContractId].tenantSbtId] = rentContractIdToRentContract[_rentContractId].id;
        sbtTokenIdToRentHistoryIds[rentContractIdToRentContract[_rentContractId].tenantSbtId].push(_rentContractId);
        propertyIdToRentHistoryIds[_propertyNftId].push(_rentContractId);

        listedProperties.remove(_propertyNftId);
        emit RentContractConfirmed(_propertyNftId, _rentContractId);
    }

    function terminateRentContract(uint256 _propertyNftId, uint256 _rentContractId) external {
        if (
            msg.sender == nftTokenIdToOwner[_propertyNftId] ||
            msg.sender == tenantManager.getTokenOwner(rentContractIdToRentContract[_rentContractId].tenantSbtId)
        ) {
            rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Canceled;
            rentContractIdToRentContract[_rentContractId].expiryTimestamp = block.timestamp;
            tokenIdToProperty[_propertyNftId].rentContractId = 0;
            tokenIdToProperty[_propertyNftId].isRented = false;
            tenantCurrentContractId[rentContractIdToRentContract[_rentContractId].tenantSbtId] = 0;
        } else {
            revert MainContract__CancelFailed(msg.sender, _propertyNftId);
        }
    }

    function cancelRentApplication(uint256 _propertyNftId, uint256 _rentContractId) external {
        if (
            rentContractIdToRentContract[_rentContractId].status == RentContractStatus.Waiting &&
            (msg.sender == nftTokenIdToOwner[_propertyNftId] ||
                msg.sender == tenantManager.getTokenOwner(rentContractIdToRentContract[_rentContractId].tenantSbtId))
        ) {
            rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Canceled;
        } else {
            revert MainContract__CancelFailed(msg.sender, _propertyNftId);
        }
    }

    // Chainlink Price Feeds
    // Network: Sepolia Aggregator: ETH/USD Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    function getWEIAmountInUSD(uint256 weiAmount) public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        uint256 decimals = 8;
        uint256 ethPrice = uint256(answer);
        uint256 weiAmountInUsd = (ethPrice * weiAmount) / 10 ** decimals / 10 ** 18;
        return weiAmountInUsd;
    }

    // Getters
    function getListedPropertiesIds() public view returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](listedProperties.length());
        for (uint256 i = 0; i < listedProperties.length(); i++) {
            ids[i] = listedProperties.at(i);
        }
        return ids;
    }

    function getListedProperties() public view returns (Property[] memory properties) {
        uint256[] memory listedPropertiesIds = getListedPropertiesIds();
        properties = new Property[](listedPropertiesIds.length);
        for (uint256 i = 1; i <= listedPropertiesIds.length; i++) {
            properties[i - 1] = tokenIdToProperty[listedPropertiesIds[i - 1]];
        }
    }

    function getUserProperties(address user) public view returns (Property[] memory properties) {
        uint256[] memory userProperties = ownerToNftTokenIds[user];
        properties = new Property[](userProperties.length);
        for (uint256 i = 1; i <= userProperties.length; i++) {
            properties[i - 1] = tokenIdToProperty[userProperties[i - 1]];
        }
    }

    function getRentContract(uint256 contractId) public view returns (RentContract memory rentContract) {
        rentContract = rentContractIdToRentContract[contractId];
        return rentContract;
    }

    function getProperty(uint256 propertyId) public view returns (Property memory property) {
        property = tokenIdToProperty[propertyId];
        return property;
    }

    function getPropertyContractsIds(uint256 nftTokenId) public view returns (uint256[] memory) {
        return nftTokenIdToContractsIds[nftTokenId];
    }

    function getTenantContractsIds(uint256 sbtTokenId) public view returns (uint256[] memory) {
        return sbtIdToContractsIds[sbtTokenId];
    }

    function getPropertyRentContracts(uint256 nftTokenId) public view returns (RentContract[] memory rentContracts) {
        uint256[] memory rentContractsIds = nftTokenIdToContractsIds[nftTokenId];
        rentContracts = new RentContract[](rentContractsIds.length);
        for (uint256 i = 1; i <= rentContractsIds.length; i++) {
            rentContracts[i - 1] = rentContractIdToRentContract[rentContractsIds[i - 1]];
        }
    }

    function getTenantRentContracts(uint256 sbtTokenId) public view returns (RentContract[] memory rentContracts) {
        uint256[] memory rentContractsIds = sbtIdToContractsIds[sbtTokenId];
        rentContracts = new RentContract[](rentContractsIds.length);
        for (uint256 i = 1; i <= rentContractsIds.length; i++) {
            rentContracts[i - 1] = rentContractIdToRentContract[rentContractsIds[i - 1]];
        }
    }

    function getTenantRentHistory(uint256 sbtTokenId) public view returns (RentContract[] memory rentContracts) {
        uint256[] memory rentContractsIds = sbtTokenIdToRentHistoryIds[sbtTokenId];
        rentContracts = new RentContract[](rentContractsIds.length);
        for (uint256 i = 1; i <= rentContractsIds.length; i++) {
            rentContracts[i - 1] = rentContractIdToRentContract[rentContractsIds[i - 1]];
        }
    }

    function getPropertyRentHistory(uint256 propertyId) public view returns (RentContract[] memory rentContracts) {
        uint256[] memory rentContractsIds = propertyIdToRentHistoryIds[propertyId];
        rentContracts = new RentContract[](rentContractsIds.length);
        for (uint256 i = 1; i <= rentContractsIds.length; i++) {
            rentContracts[i - 1] = rentContractIdToRentContract[rentContractsIds[i - 1]];
        }
    }

    function getPropertyOwner(uint256 propertyNftId) public view returns (address owner) {
        owner = nftTokenIdToOwner[propertyNftId];
        return owner;
    }

    function getTenantCurrentContractId(uint256 sbtTokenId) public view returns (uint256) {
        uint256 contractId = tenantCurrentContractId[sbtTokenId];
        if (contractId == 0) {
            revert MainContract__DoesntHaveCurrentContract();
        }
        return contractId;
    }

    function getUserEmail(address user) public view returns (string memory) {
        return addressToEmail[user];
    }

    function getUserPhoneNumber(address user) public view returns (string memory) {
        return addressToPhoneNumber[user];
    }

    function getNumberOfProperties() public view returns (uint256) {
        return numberOfProperties;
    }

    function getNumberOfContracts() public view returns (uint256) {
        return numberOfContracts;
    }
}
