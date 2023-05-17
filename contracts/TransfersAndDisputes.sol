// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./MainContract.sol";
import "./TenantManager.sol";

// SECURITY DEPOSIT MUST BE TRANSFERED IN 5 DAYS AFTER CONFIRMATION, ELSE CONTRACT STATUS IS CANCELED
error RentApp__NotEnoughAmount();
error RentApp__WithdrawFailed();
error RentApp__DisputeCreationFailed(address caller, uint256 propertyNftId);

contract TransfersAndDisputes {
    MainContract public mainContract;
    address private mainContractAddress;
    TenantManager public tenantManager;
    address private tenantManagerAddress;

    struct Payment {
        uint256 id;
        uint256 timestamp;
        uint256 amount;
    }

    struct Dispute {
        uint256 id;
        string description;
        bool solvedByLandlord;
        bool solvedByTenant;
    }
    enum RentContractStatus {
        Waiting,
        Confirmed,
        Canceled
    }

    uint256 public numberOfDisputes;
    uint256 public numberOfPayments;

    mapping(uint256 => uint256) public rentContractIdToDeposit;
    mapping(uint256 => uint256) public nftTokenIdToBalance;
    mapping(uint256 => uint256) public rentContractIdToAmountOfPaidRent;
    mapping(uint256 => uint256[]) public rentContractIdToPaymentsIds;
    mapping(uint256 => uint256[]) public rentContractIdToDisputesIds;
    mapping(uint256 => bool) public rentContractIdToAllowedDepositRelease;
    mapping(uint256 => Dispute) public disputeIdToDispute;
    mapping(uint256 => Payment) public paymentIdToPayment;

    constructor(address _mainContractAddress, address _tenantManagerAddress) {
        mainContractAddress = _mainContractAddress;
        tenantManagerAddress = _tenantManagerAddress;
        mainContract = MainContract(mainContractAddress);
        tenantManager = TenantManager(tenantManagerAddress);
    }

    function transferSecurityDeposit(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        MainContract.Property memory property = mainContract.getProperty(_propertyNftId);
        if (rentContract.status != MainContract.RentContractStatus.Confirmed || rentContract.propertyNftId != property.propertyNftId) {
            revert RentApp__InvalidRentContract();
        }
        if (msg.value < rentContract.depositAmount) {
            revert RentApp__NotEnoughAmount();
        }
        rentContractIdToAllowedDepositRelease[_rentContractId] = false;
        rentContractIdToDeposit[_rentContractId] = rentContractIdToDeposit[_rentContractId] + msg.value;
        uint256 paymentId = numberOfPayments;
        Payment storage payment = paymentIdToPayment[paymentId];
        payment.id = paymentId;
        payment.timestamp = block.timestamp;
        payment.amount = msg.value;
        numberOfPayments++;
        rentContractIdToPaymentsIds[_rentContractId].push(paymentId);
    }

    function transferRent(uint256 _propertyNftId, uint256 _rentContractId) external payable {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        MainContract.Property memory property = mainContract.getProperty(_propertyNftId);
        if (rentContract.status != MainContract.RentContractStatus.Confirmed || rentContract.propertyNftId != property.propertyNftId) {
            revert RentApp__InvalidRentContract();
        }
        if (msg.value < rentContract.rentalPrice) {
            revert RentApp__NotEnoughAmount();
        }
        nftTokenIdToBalance[_propertyNftId] = nftTokenIdToBalance[_propertyNftId] + msg.value;
        rentContractIdToAmountOfPaidRent[_rentContractId] = rentContractIdToAmountOfPaidRent[_rentContractId] + msg.value;
        uint256 paymentId = numberOfPayments;
        Payment storage payment = paymentIdToPayment[paymentId];
        payment.id = paymentId;
        payment.timestamp = block.timestamp;
        payment.amount = msg.value;
        numberOfPayments++;
        rentContractIdToPaymentsIds[_rentContractId].push(paymentId);
    } // If the balance is not enough in the end of the month, a owner should be informed

    function withdrawProceeds(uint256 _propertyNftId) external {
        uint256 proceeds = nftTokenIdToBalance[_propertyNftId];
        address owner = mainContract.getPropertyOwner(_propertyNftId);
        if (proceeds <= 0 || msg.sender != owner) {
            revert RentApp__WithdrawFailed();
        }
        nftTokenIdToBalance[_propertyNftId] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert RentApp__WithdrawFailed();
        }
    }

    function allowDepositRelease(uint256 _rentContractId) external {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 nftTokenId = rentContract.propertyNftId;
        address owner = mainContract.getPropertyOwner(nftTokenId);
        if (msg.sender == owner) {
            rentContractIdToAllowedDepositRelease[_rentContractId] = true;
        } else {
            revert RentApp__AllowDepositReleaseFailed(msg.sender, _rentContractId);
        }
    }

    function releaseDeposit(uint256 _rentContractId) external {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 tenantId = rentContract.tenantSbtId;
        uint256 expiryTimestamp = rentContract.expiryTimestamp;
        uint256 deposit = rentContractIdToDeposit[_rentContractId];
        address tenant = tenantManager.getTokenOwner(tenantId);
        if (
            msg.sender == tenant && deposit > 0 && expiryTimestamp < block.timestamp && rentContractIdToAllowedDepositRelease[_rentContractId] == true
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

    function createDispute(uint256 _rentContractId, string memory _description) external {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 propertyNftId = rentContract.propertyNftId;
        uint256 tenantId = rentContract.tenantSbtId;
        address owner = mainContract.getPropertyOwner(propertyNftId);
        address tenant = tenantManager.getTokenOwner(tenantId);
        if (msg.sender == owner || msg.sender == tenant) {
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
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 propertyNftId = rentContract.propertyNftId;
        uint256 tenantId = rentContract.tenantSbtId;
        address owner = mainContract.getPropertyOwner(propertyNftId);
        address tenant = tenantManager.getTokenOwner(tenantId);
        if (msg.sender == owner) {
            disputeIdToDispute[_disputeId].solvedByLandlord = true;
        } else if (msg.sender == tenant) {
            disputeIdToDispute[_disputeId].solvedByTenant = true;
        } else {
            revert RentApp__DisputeCreationFailed(msg.sender, propertyNftId);
        }
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
