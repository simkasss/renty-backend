const { Description } = require("@ethersproject/properties")
const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("TransfersAndDisputes Unit Tests", function () {
          let deployer, transfersAndDisputes, user, mainContract, tenantManager, transfersAndDisputesUserConnected, transfersAndDisputesOwnerConnected

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])

              mainContract = await ethers.getContract("MainContract")
              transfersAndDisputes = await ethers.getContract("TransfersAndDisputes")
              tenantManager = await ethers.getContract("TenantManager")
              transfersAndDisputesUserConnected = await ethers.getContract("TransfersAndDisputes", user)
              transfersAndDisputesOwnerConnected = await ethers.getContract("TransfersAndDisputes", deployer)
          })
          describe("transferSecurityDeposit", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
              })
              it.only("transfers deposit and creates a payment ", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  const paymentId = await transfersAndDisputesUserConnected.getNumberOfPayments()

                  await mainContract.acceptRentContract(id, contractId)

                  await transfersAndDisputesUserConnected.transferSecurityDeposit(id, contractId, { value: 10 })
                  const transferedDeposit = await transfersAndDisputesUserConnected.getDeposit(contractId)
                  const payment = await transfersAndDisputesUserConnected.getPayment(paymentId)
                  const numberOfPayments = await transfersAndDisputesUserConnected.getNumberOfPayments()

                  assert.equal(payment[0], 0)
                  assert.equal(payment[2], 10)
                  assert.equal(numberOfPayments, 1)
                  assert.equal(transferedDeposit, 10)
              })
              it("reverts if deposit amount is not enough", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await expect(transfersAndDisputesUserConnected.transferSecurityDeposit(id, contractId, { value: 5 })).to.be.revertedWith(
                      "TransfersAndDisputes__NotEnoughAmount"
                  )
              })
              it("reverts if rent contract is not signed", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(transfersAndDisputesUserConnected.transferSecurityDeposit(id, contractId, { value: 10 })).to.be.revertedWith(
                      "TransfersAndDisputes__InvalidRentContract"
                  )
              })
          })
          describe("transferRent", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
              })
              it("reverts if rent amount is not enough", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await expect(transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 5 })).to.be.revertedWith(
                      "TransfersAndDisputes__NotEnoughAmount"
                  )
              })
              it("reverts if rent contract is not signed", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 30 })).to.be.revertedWith(
                      "TransfersAndDisputes__InvalidRentContract"
                  )
              })
              it("transfers rent", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 30 })
                  const getPaidRent = await transfersAndDisputesUserConnected.getAmountOfPaidRent(contractId)
                  assert.equal(getPaidRent, 30)
              })
          })
          describe("withdrawProceeds", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
              })
              it("reverts if msg.sender is not owner of the property", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 30 })
                  await expect(transfersAndDisputesUserConnected.withdrawProceeds(id)).to.be.revertedWith("TransfersAndDisputes__WithdrawFailed")
              })
              it("reverts if there are no proceeds", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await expect(transfersAndDisputesOwnerConnected.withdrawProceeds(id)).to.be.revertedWith("TransfersAndDisputes__WithdrawFailed")
              })
              it("lets withdraw and updates owners proceeds balance", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)

                  await transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 30 })
                  const balanceBeforeWithdrawal = await transfersAndDisputesUserConnected.getPropertyBalance(id)
                  await transfersAndDisputesOwnerConnected.withdrawProceeds(id)
                  const balanceAfterWithdrawal = await transfersAndDisputesUserConnected.getPropertyBalance(id)
                  assert.equal(balanceBeforeWithdrawal, 30)
                  assert.equal(balanceAfterWithdrawal, 0)
              })
          })
          describe("allowDepositRelease", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.transferSecurityDeposit(id, contractId, { value: 10 })
                  const transferedDeposit = await transfersAndDisputesUserConnected.getDeposit(contractId)
              })
              it("gives permission to release deposit", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  const depositReleasePermissionBefore = await transfersAndDisputesUserConnected.depositReleasePermission(contractId)
                  await transfersAndDisputesOwnerConnected.allowDepositRelease(contractId)
                  const depositReleasePermissionAfter = await transfersAndDisputesUserConnected.depositReleasePermission(contractId)
                  assert.equal(depositReleasePermissionBefore, false)
                  assert.equal(depositReleasePermissionAfter, true)
              })
              it("reverts if not property owner tries to give permission for deposit release", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(transfersAndDisputesUserConnected.allowDepositRelease(contractId)).to.be.revertedWith(
                      "TransfersAndDisputes__AllowDepositReleaseFailed"
                  )
                  const depositReleasePermissionAfter = await transfersAndDisputesUserConnected.depositReleasePermission(contractId)

                  assert.equal(depositReleasePermissionAfter, false)
              })
          })
          describe("releaseDeposit", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.transferSecurityDeposit(id, contractId, { value: 10 })
                  await transfersAndDisputesOwnerConnected.allowDepositRelease(contractId)
              })
              it("lets tenant to withdraw deposit", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  const depositBefore = await transfersAndDisputesUserConnected.getDeposit(contractId)
                  await mainContract.terminateRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.releaseDeposit(contractId)
                  const depositAfter = await transfersAndDisputesUserConnected.getDeposit(contractId)
                  assert.equal(depositBefore, 10)
                  assert.equal(depositAfter, 0)
              })
              it("reverts if contract is not expired", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(transfersAndDisputesUserConnected.releaseDeposit(contractId)).to.be.revertedWith(
                      "TransfersAndDisputes__WithdrawFailed"
                  )
              })
              it("reverts if not tenant tries to withdraw deposit", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.terminateRentContract(id, contractId)
                  await expect(transfersAndDisputesOwnerConnected.releaseDeposit(contractId)).to.be.revertedWith(
                      "TransfersAndDisputes__WithdrawFailed"
                  )
              })
          })
          describe("createDispute", function () {
              beforeEach(async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
              })

              it("reverts if rent contract is not confirmed", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(transfersAndDisputesUserConnected.createDispute(contractId, "random dispute")).to.be.revertedWith(
                      "TransfersAndDisputes__DisputeCreationFailed"
                  )
              })
              it.only("allows to create a dispute", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.createDispute(contractId, "random dispute")
                  const disputes = await transfersAndDisputesUserConnected.getRentContractDisputes(contractId)
                  const disputeId = disputes[0][0]
                  const disputeDescription = disputes[0][1]
                  assert.equal(disputeId, 0)
                  assert.equal(disputeDescription, "random dispute")
              })
          })
          describe("getRentContractPaymentHistory", function () {
              it.only("gets array of rent contract payments ", async function () {
                  id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  await transfersAndDisputesUserConnected.transferRent(id, contractId, { value: 30 })
                  const getPaidRent = await transfersAndDisputesUserConnected.getAmountOfPaidRent(contractId)
                  assert.equal(getPaidRent, 30)
                  const payments = await transfersAndDisputesUserConnected.getRentContractPaymentHistory(contractId)
                  const firstRentPayment = payments[0][2]
                  assert.equal(firstRentPayment, 30)
              })
          })
      })
