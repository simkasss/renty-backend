// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./MainContract.sol";
import "./TenantManager.sol";

// SECURITY DEPOSIT MUST BE TRANSFERED IN 5 DAYS AFTER CONFIRMATION, ELSE CONTRACT STATUS IS CANCELED
error TransfersAndDisputes__NotEnoughAmount();
error TransfersAndDisputes__InvalidRentContract();
error TransfersAndDisputes__WithdrawFailed();
error TransfersAndDisputes__AllowDepositReleaseFailed();
error TransfersAndDisputes__DisputeCreationFailed();
error TransfersAndDisputes__TransferFailed();
error TransfersAndDisputes__SolveDisputeFailed();

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
    mapping(address => uint256) public addressToBalance;
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
            revert TransfersAndDisputes__InvalidRentContract();
        }
        if (msg.value < rentContract.depositAmount) {
            revert TransfersAndDisputes__NotEnoughAmount();
        }

        rentContractIdToAllowedDepositRelease[_rentContractId] = false;
        rentContractIdToDeposit[_rentContractId] += msg.value;
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
        address landlord = mainContract.getPropertyOwner(_propertyNftId);
        if (rentContract.status != MainContract.RentContractStatus.Confirmed || rentContract.propertyNftId != property.propertyNftId) {
            revert TransfersAndDisputes__InvalidRentContract();
        }
        if (msg.value < rentContract.rentalPrice) {
            revert TransfersAndDisputes__NotEnoughAmount();
        }

        addressToBalance[landlord] += msg.value;
        rentContractIdToAmountOfPaidRent[_rentContractId] += msg.value;
        uint256 paymentId = numberOfPayments;
        Payment storage payment = paymentIdToPayment[paymentId];
        payment.id = paymentId;
        payment.timestamp = block.timestamp;
        payment.amount = msg.value;
        numberOfPayments++;
        rentContractIdToPaymentsIds[_rentContractId].push(paymentId);
    } // If the balance is not enough in the end of the month, a owner should be informed

    function withdrawProceeds(address _user, uint256 _amount) external {
        uint256 proceeds = addressToBalance[_user];
        if (proceeds < _amount) {
            revert TransfersAndDisputes__WithdrawFailed();
        }
        addressToBalance[_user] -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert TransfersAndDisputes__WithdrawFailed();
        }
    }

    function allowDepositRelease(uint256 _rentContractId) external {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 nftTokenId = rentContract.propertyNftId;
        address owner = mainContract.getPropertyOwner(nftTokenId);
        if (msg.sender == owner) {
            rentContractIdToAllowedDepositRelease[_rentContractId] = true;
        } else {
            revert TransfersAndDisputes__AllowDepositReleaseFailed();
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
                revert TransfersAndDisputes__WithdrawFailed();
            }
        } else {
            revert TransfersAndDisputes__WithdrawFailed();
        }
    }

    function createDispute(uint256 _rentContractId, string memory _description) external {
        MainContract.RentContract memory rentContract = mainContract.getRentContract(_rentContractId);
        uint256 propertyNftId = rentContract.propertyNftId;
        uint256 tenantId = rentContract.tenantSbtId;
        address owner = mainContract.getPropertyOwner(propertyNftId);
        address tenant = tenantManager.getTokenOwner(tenantId);
        if (rentContract.status == MainContract.RentContractStatus.Confirmed && (msg.sender == owner || msg.sender == tenant)) {
            uint256 disputeId = numberOfDisputes;
            Dispute storage dispute = disputeIdToDispute[disputeId];
            dispute.id = disputeId;
            dispute.description = _description;
            dispute.solvedByLandlord = false;
            dispute.solvedByTenant = false;
            numberOfDisputes++;
            rentContractIdToDisputesIds[_rentContractId].push(dispute.id);
        } else {
            revert TransfersAndDisputes__DisputeCreationFailed();
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
            revert TransfersAndDisputes__SolveDisputeFailed();
        }
    }

    function getDeposit(uint256 _rentContractId) public view returns (uint256 transferedDepositAmount) {
        transferedDepositAmount = rentContractIdToDeposit[_rentContractId];
    }

    function getAmountOfPaidRent(uint256 _rentContractId) public view returns (uint256 rentPaid) {
        rentPaid = rentContractIdToAmountOfPaidRent[_rentContractId];
    }

    function getRentContractPaymentHistory(uint256 _rentContractId) public view returns (Payment[] memory paymenthistory) {
        uint256[] memory paymentsIds = rentContractIdToPaymentsIds[_rentContractId];
        paymenthistory = new Payment[](paymentsIds.length);
        for (uint256 i = 1; i <= paymentsIds.length; i++) {
            paymenthistory[i - 1] = paymentIdToPayment[paymentsIds[i - 1]];
        }
    }

    function getRentContractDisputes(uint256 _rentContractId) public view returns (Dispute[] memory disputes) {
        uint256[] memory disputeIds = rentContractIdToDisputesIds[_rentContractId];
        disputes = new Dispute[](disputeIds.length);
        for (uint256 i = 1; i <= disputeIds.length; i++) {
            disputes[i - 1] = disputeIdToDispute[disputeIds[i - 1]];
        }
        return disputes;
    }

    function getUserBalance(address _user) public view returns (uint256) {
        return addressToBalance[_user];
    }

    function depositReleasePermission(uint256 _rentContractId) public view returns (bool) {
        return rentContractIdToAllowedDepositRelease[_rentContractId];
    }

    function getPayment(uint256 _paymentId) public view returns (Payment memory payment) {
        return paymentIdToPayment[_paymentId];
    }

    function getNumberOfPayments() public view returns (uint256) {
        return numberOfPayments;
    }
}
