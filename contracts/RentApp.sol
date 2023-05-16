/* This contract will handle management of rental agreements between property owners and tenants:
the creation, signing, storage, the payment of rent and the holding of security deposits in escrow.*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./PropertyNFT.sol";
import "./TenantSoulboundToken.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error RentApp__NotOwner(address caller, uint256 tokenId);
error RentApp__InvalidRentContract();
error RentApp__NotEnoughAmount();
error RentApp__WithdrawFailed();
error RentApp__CancelFailed(address caller, uint256 propertyNftId);
error RentApp__DisputeCreationFailed(address caller, uint256 propertyNftId);
error RentApp__PropertyIsNotListed();
error RentApp__AlreadyHasSBT(address caller);
error RentApp__OwnerCantBeTenant();
error RentApp__DoesntHaveSBT(address user);
error RentApp__AllowDepositReleaseFailed(address owner, uint256 rentContractId);

contract RentApp {
    PropertyNft public propertyNFT;
    TenantSoulboundToken public tenantSoulboundToken;
    AggregatorV3Interface private priceFeed;
    address private propertyNftContractAddress;
    address private tenantSoulboundContractAddress;
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
    struct Tenant {
        uint256 sbtId; //address lives on the SBT
        string name;
        uint256 currentRentContractId;
        RentContract[] rentHistory;
    }

    struct Payment {
        uint256 id;
        string name;
        uint256 timestamp;
        uint256 amount;
    }

    struct Dispute {
        uint256 id;
        string description;
        bool solvedByLandlord;
        bool solvedByTenant;
    }

    event PropertyListed(address indexed owner, uint256 indexed tokenId);
    event PropertyRemovedFromList(address indexed owner, uint256 indexed tokenId);
    event PropertyCreated(address indexed owner, uint256 indexed propertyId);
    event SoulboundMinted(address indexed tenant, uint256 indexed tokenId);
    event RentContractCreated(uint256 indexed tenantTokenId, uint256 indexed rentContractId);
    event RentContractConfirmed(uint256 indexed propertyTokenId, uint256 indexed rentContractId);

    EnumerableSet.UintSet private listedProperties;
    uint256 public numberOfProperties;
    uint256 public numberOfTenants;
    uint256 public numberOfContracts;
    uint256 public numberOfDisputes;
    uint256 public numberOfPayments;

    mapping(uint256 => address) public nftTokenIdToOwner;
    mapping(address => uint256[]) public ownerToNftTokenIds;
    mapping(address => uint256) public ownerToSbtTokenId;
    mapping(uint256 => address) public soulboundTokenIdToOwner;
    mapping(uint256 => Property) public tokenIdToProperty;
    mapping(uint256 => Tenant) public tokenIdToTenant;
    mapping(address => bool) public ownsTSBT;
    mapping(uint256 => RentContract) public rentContractIdToRentContract;
    mapping(uint256 => uint256[]) public nftTokenIdToContractsIds;
    mapping(uint256 => uint256[]) public sbtIdToContractsIds;
    mapping(uint256 => uint256) public rentContractIdToDeposit;
    mapping(uint256 => uint256) public nftTokenIdToBalance;
    mapping(uint256 => uint256) public rentContractIdToAmountOfPaidRent;
    mapping(uint256 => uint256[]) public rentContractIdToPaymentsIds;
    mapping(uint256 => uint256[]) public rentContractIdToDisputesIds;
    mapping(uint256 => bool) public rentContractIdToAllowedDepositRelease;
    mapping(uint256 => Dispute) public disputeIdToDispute;
    mapping(uint256 => Payment) public paymentIdToPayment;

    constructor(address _propertyNftContractAddress, address _tenantSoulboundContractAddress, address _priceFeedAddress) {
        propertyNftContractAddress = _propertyNftContractAddress;
        propertyNFT = PropertyNft(propertyNftContractAddress);
        tenantSoulboundContractAddress = _tenantSoulboundContractAddress;
        tenantSoulboundToken = TenantSoulboundToken(tenantSoulboundContractAddress);
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
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
    modifier onlyOneSBT() {
        if (ownsTSBT[msg.sender] == true) {
            revert RentApp__AlreadyHasSBT(msg.sender);
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

    function mintSoulboundToken(string memory _name, string memory _tokenUri) external onlyOneSBT returns (uint256) {
        uint256 tokenId = tenantSoulboundToken.mintSBT(msg.sender, _tokenUri); //This function should return tokenId
        //How can we get nftaddress?
        soulboundTokenIdToOwner[tokenId] = msg.sender;
        Tenant storage tenant = tokenIdToTenant[tokenId];
        tenant.sbtId = tokenId;
        tenant.name = _name;
        numberOfTenants++;
        ownsTSBT[msg.sender] = true;
        ownerToSbtTokenId[msg.sender] = tokenId;
        emit SoulboundMinted(msg.sender, tokenId);
        return tokenId;
    }

    function createRentContract(
        uint256 _propertyNftId,
        uint256 _tenantTokenId,
        uint256 _rentalTerm,
        uint256 _rentalPrice,
        uint256 _depositAmount,
        uint256 _startTimestamp,
        uint256 _validityTerm
    ) external onlyTSBTOwner(_tenantTokenId) {
        if (!listedProperties.contains(_propertyNftId)) {
            revert RentApp__PropertyIsNotListed();
        }
        if (soulboundTokenIdToOwner[_tenantTokenId] == nftTokenIdToOwner[_propertyNftId]) {
            revert RentApp__OwnerCantBeTenant();
        }
        numberOfContracts++;
        uint256 rentContractId = numberOfContracts;
        RentContract storage rentContract = rentContractIdToRentContract[rentContractId];
        rentContract.id = rentContractId;
        rentContract.propertyNftId = tokenIdToProperty[_propertyNftId].propertyNftId;
        rentContract.tenantSbtId = tokenIdToTenant[_tenantTokenId].sbtId;
        rentContract.rentalTerm = _rentalTerm;
        rentContract.rentalPrice = _rentalPrice;
        rentContract.depositAmount = _depositAmount;
        rentContract.startTimestamp = _startTimestamp;
        rentContract.validityTerm = _validityTerm;
        rentContract.status = RentContractStatus.Waiting;
        rentContract.propertyRentContractsAccepted = tokenIdToProperty[_propertyNftId].rentContractsAccepted;
        nftTokenIdToContractsIds[_propertyNftId].push(rentContract.id);
        sbtIdToContractsIds[tokenIdToTenant[_tenantTokenId].sbtId].push(rentContract.id);

        emit RentContractCreated(_tenantTokenId, rentContractId);
    }

    function acceptRentContract(uint256 _propertyNftId, uint256 _rentContractId) external onlyPropertyOwner(_propertyNftId) {
        if (
            tokenIdToProperty[_propertyNftId].rentContractsAccepted != rentContractIdToRentContract[_rentContractId].propertyRentContractsAccepted ||
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Waiting ||
            rentContractIdToRentContract[_rentContractId].validityTerm < block.timestamp
        ) {
            revert RentApp__InvalidRentContract();
        }
        tokenIdToProperty[_propertyNftId].rentContractsAccepted++;
        rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Confirmed;
        tokenIdToProperty[_propertyNftId].rentContractId = rentContractIdToRentContract[_rentContractId].id;

        tokenIdToProperty[_propertyNftId].isRented = true;
        rentContractIdToRentContract[_rentContractId].expiryTimestamp =
            rentContractIdToRentContract[_rentContractId].startTimestamp +
            rentContractIdToRentContract[_rentContractId].rentalTerm;
        tokenIdToTenant[rentContractIdToRentContract[_rentContractId].tenantSbtId].currentRentContractId = rentContractIdToRentContract[
            _rentContractId
        ].id;
        tokenIdToTenant[rentContractIdToRentContract[_rentContractId].tenantSbtId].rentHistory.push(rentContractIdToRentContract[_rentContractId]);
        rentContractIdToAllowedDepositRelease[_rentContractId] = false;
        listedProperties.remove(_propertyNftId);
        emit RentContractConfirmed(_propertyNftId, _rentContractId);
    } // ALL OTHER APPLICATONS SHOULD BE CANCELED, SHOW THIS IN UI

    // SECURITY DEPOSIT MUST BE TRANSFERED IN 5 DAYS AFTER CONFIRMATION, ELSE CONTRACT STATUS IS CANCELED

    function transferSecurityDeposit(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        if (
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Confirmed ||
            rentContractIdToRentContract[_rentContractId].propertyNftId != tokenIdToProperty[_propertyNftId].propertyNftId
        ) {
            revert RentApp__InvalidRentContract();
        }
        if (msg.value < rentContractIdToRentContract[_rentContractId].depositAmount) {
            revert RentApp__NotEnoughAmount();
        }

        rentContractIdToDeposit[_rentContractId] = rentContractIdToDeposit[_rentContractId] + msg.value;
        uint256 paymentId = numberOfPayments;
        Payment storage payment = paymentIdToPayment[paymentId];
        payment.id = paymentId;
        payment.name = "Security Deposit Payment";
        payment.timestamp = block.timestamp;
        payment.amount = msg.value;
        numberOfPayments++;
        rentContractIdToPaymentsIds[_rentContractId].push(paymentId);
    }

    function transferRent(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        if (
            rentContractIdToRentContract[_rentContractId].status != RentContractStatus.Confirmed ||
            rentContractIdToRentContract[_rentContractId].propertyNftId != tokenIdToProperty[_propertyNftId].propertyNftId
        ) {
            revert RentApp__InvalidRentContract();
        }
        if (msg.value < rentContractIdToRentContract[_rentContractId].rentalPrice) {
            revert RentApp__NotEnoughAmount();
        }
        nftTokenIdToBalance[_propertyNftId] = nftTokenIdToBalance[_propertyNftId] + msg.value;
        rentContractIdToAmountOfPaidRent[_rentContractId] = rentContractIdToAmountOfPaidRent[_rentContractId] + msg.value;
        uint256 paymentId = numberOfPayments;
        Payment storage payment = paymentIdToPayment[paymentId];
        payment.id = paymentId;
        payment.name = "Rent Payment";
        payment.timestamp = block.timestamp;
        payment.amount = msg.value;
        numberOfPayments++;
        rentContractIdToPaymentsIds[_rentContractId].push(paymentId);
    } // If the balance is not enough in the end of the month, a owner should be informed

    function withdrawProceeds(uint256 _propertyNftId) external onlyPropertyOwner(_propertyNftId) {
        uint256 proceeds = nftTokenIdToBalance[_propertyNftId];
        if (proceeds <= 0) {
            revert RentApp__WithdrawFailed();
        }
        nftTokenIdToBalance[_propertyNftId] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert RentApp__WithdrawFailed();
        }
    }

    function allowDepositRelease(uint256 _rentContractId) external {
        uint256 nftTokenId = rentContractIdToRentContract[_rentContractId].propertyNftId;
        address owner = nftTokenIdToOwner[nftTokenId];
        if (msg.sender == owner) {
            rentContractIdToAllowedDepositRelease[_rentContractId] = true;
        } else {
            revert RentApp__AllowDepositReleaseFailed(msg.sender, _rentContractId);
        }
    }

    function releaseDeposit(uint256 _rentContractId) external {
        uint256 tenantId = rentContractIdToRentContract[_rentContractId].tenantSbtId;
        uint256 expiryTimestamp = rentContractIdToRentContract[_rentContractId].expiryTimestamp;
        uint256 deposit = rentContractIdToDeposit[_rentContractId];
        if (
            msg.sender == soulboundTokenIdToOwner[tenantId] &&
            deposit > 0 &&
            expiryTimestamp < block.timestamp &&
            rentContractIdToAllowedDepositRelease[_rentContractId] == true
        ) {
            rentContractIdToDeposit[_rentContractId] = 0;
            (bool success, ) = payable(msg.sender).call{value: deposit}("");
            if (!success) {
                revert RentApp__WithdrawFailed();
            }
        } else {
            revert RentApp__WithdrawFailed();
        }
    }

    function terminateRentContract(uint256 _propertyNftId, uint256 _rentContractId) external {
        if (
            msg.sender == nftTokenIdToOwner[_propertyNftId] ||
            msg.sender == soulboundTokenIdToOwner[rentContractIdToRentContract[_rentContractId].tenantSbtId]
        ) {
            rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Canceled;
            tokenIdToProperty[_propertyNftId].rentContractId = 0;
            uint256 disputeId = numberOfDisputes;
            Dispute storage dispute = disputeIdToDispute[disputeId];
            dispute.id = disputeId;
            dispute.description = "Terminate Rent Contract";
            dispute.solvedByLandlord = false;
            dispute.solvedByTenant = false;
            numberOfDisputes++;
            rentContractIdToDisputesIds[_rentContractId].push(dispute.id);
            tokenIdToTenant[rentContractIdToRentContract[_rentContractId].tenantSbtId].currentRentContractId = 0;
        } else {
            revert RentApp__CancelFailed(msg.sender, _propertyNftId);
        }
    }

    function createDispute(uint256 _rentContractId, string memory _description) external {
        uint256 propertyNftId = rentContractIdToRentContract[_rentContractId].propertyNftId;
        uint256 tenantId = rentContractIdToRentContract[_rentContractId].tenantSbtId;
        if (msg.sender == nftTokenIdToOwner[propertyNftId] || msg.sender == soulboundTokenIdToOwner[tenantId]) {
            uint256 disputeId = numberOfDisputes;
            Dispute storage dispute = disputeIdToDispute[disputeId];
            dispute.id = disputeId;
            dispute.description = _description;
            dispute.solvedByLandlord = false;
            dispute.solvedByTenant = false;
            numberOfDisputes++;
            rentContractIdToDisputesIds[_rentContractId].push(dispute.id);
        } else {
            revert RentApp__DisputeCreationFailed(msg.sender, propertyNftId);
        }
    }

    function solveDispute(uint256 _rentContractId, uint256 _disputeId) external {
        uint256 propertyNftId = rentContractIdToRentContract[_rentContractId].propertyNftId;
        uint256 tenantId = rentContractIdToRentContract[_rentContractId].tenantSbtId;
        if (msg.sender == nftTokenIdToOwner[propertyNftId]) {
            disputeIdToDispute[_disputeId].solvedByLandlord = true;
        } else if (msg.sender == soulboundTokenIdToOwner[tenantId]) {
            disputeIdToDispute[_disputeId].solvedByTenant = true;
        } else {
            revert RentApp__DisputeCreationFailed(msg.sender, propertyNftId);
        }
    }

    function cancelRentApplication(uint256 _propertyNftId, uint256 _rentContractId) external {
        if (
            rentContractIdToRentContract[_rentContractId].status == RentContractStatus.Waiting &&
            (msg.sender == nftTokenIdToOwner[_propertyNftId] ||
                msg.sender == soulboundTokenIdToOwner[rentContractIdToRentContract[_rentContractId].tenantSbtId])
        ) {
            rentContractIdToRentContract[_rentContractId].status = RentContractStatus.Canceled;
        } else {
            revert RentApp__CancelFailed(msg.sender, _propertyNftId);
        }
    }

    // Chainlink Price Feeds
    // Network: Sepolia Aggregator: ETH/USD Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    function getETHAmountInUSD(uint256 ethAmount) public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        uint256 ethPrice = uint256(answer * 10000000000);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        return ethAmountInUsd;
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

    function getSbtTokenId(address tokenOwner) public view returns (uint256) {
        if (!ownsTSBT[tokenOwner]) {
            revert RentApp__DoesntHaveSBT(tokenOwner);
        }
        uint256 sbtTokenId = ownerToSbtTokenId[tokenOwner];
        return sbtTokenId;
    }

    function getTenant(uint256 sbtTokenId) public view returns (Tenant memory tenant) {
        tenant = tokenIdToTenant[sbtTokenId];
        return tenant;
    }

    function getDeposit(uint256 _rentContractId) public view returns (uint256 transferedDepositAmount) {
        transferedDepositAmount = rentContractIdToDeposit[_rentContractId];
        return transferedDepositAmount;
    }

    function getAmountOfPaidRent(uint256 _rentContractId) public view returns (uint256 rentPaid) {
        rentPaid = rentContractIdToAmountOfPaidRent[_rentContractId];
        return rentPaid;
    }

    function getRentContractPaymentHistory(uint256 _rentContractId) public view returns (Payment[] memory paymenthistory) {
        uint256[] memory paymentsIds = rentContractIdToPaymentsIds[_rentContractId];
        paymenthistory = new Payment[](paymentsIds.length);
        for (uint256 i = 0; i <= paymentsIds.length; i++) {
            paymenthistory[i] = paymentIdToPayment[paymentsIds[i]];
        }
        return paymenthistory;
    }

    function getRentContractDisputes(uint256 _rentContractId) public view returns (Dispute[] memory disputes) {
        uint256[] memory disputeIds = rentContractIdToDisputesIds[_rentContractId];
        disputes = new Dispute[](disputeIds.length);
        for (uint256 i = 0; i <= disputeIds.length; i++) {
            disputes[i] = disputeIdToDispute[disputeIds[i]];
        }
        return disputes;
    }
}
