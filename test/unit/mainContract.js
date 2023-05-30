const { assert, expect } = require("chai")
const { BigNumber } = require("ethers")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Main Contract Unit Tests", function () {
          let deployer, mainContract, tenantManager, user, user2

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              user2 = accounts[2]
              await deployments.fixture(["all"])
              mainContract = await ethers.getContract("MainContract")
              tenantManager = await ethers.getContract("TenantManager")
          })
          describe("createPropery", function () {
              it("assigns owner correctly", async function () {
                  const createProperty = await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  await createProperty.wait(1)
                  const owner = await mainContract.getPropertyOwner(0)
                  assert.equal(owner, deployer.address)
              })
              it("emits event after creating property", async function () {
                  await expect(
                      mainContract.createProperty(
                          "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                          "Ben",
                          "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                      )
                  ).to.emit(mainContract, "PropertyCreated")
              })
              it("updates property counter", async function () {
                  const counterBefore = await mainContract.getNumberOfProperties()
                  const createProperty = await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  await createProperty.wait(1)
                  const counterAfter = await mainContract.getNumberOfProperties()

                  assert.equal(counterBefore, 0)
                  assert.equal(counterAfter, 1)
              })
          })
          describe("listProperty", function () {
              it("adds property to listed properties", async function () {
                  const id = await mainContract.getNumberOfProperties()
                  const mint = mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )

                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  const listProperty = await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      id,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  await listProperty.wait(1)
                  const listedProperties = await mainContract.getListedPropertiesIds()
                  assert.equal(listedProperties.toString().includes(id), true)
              })
              it("emits event after listing a property", async function () {
                  const mint = await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )

                  const rentalTerm = 60 * 60 * 24 * 30 //month

                  await expect(
                      mainContract.listProperty(
                          "nice flat with a lot of amenities",
                          0,
                          rentalTerm,
                          30,
                          10,
                          ["mockPhotoHash1", "mockPhotoHash2"],
                          "mockHashOfTermsAndconditions"
                      )
                  ).to.emit(mainContract, "PropertyListed")
              })
          })
          describe("updateProperty", function () {
              it("updates property correctly", async function () {
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      0,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const propertyBefore = await mainContract.getProperty(0)
                  await mainContract.updateProperty(
                      propertyBefore.name.toString(),
                      propertyBefore.description.toString(),
                      0,
                      rentalTerm,
                      50,
                      30,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const propertyAfter = await mainContract.getProperty(0)
                  assert.equal(propertyBefore.name, propertyAfter.name)
                  assert.equal(propertyBefore.description, propertyAfter.description)
                  assert.equal(propertyBefore.propertyNftId.toString(), propertyAfter.propertyNftId.toString())
                  assert.equal(propertyBefore.rentalTerm.toString(), propertyAfter.rentalTerm.toString())
                  assert.equal(propertyBefore.rentalPrice, 30)
                  assert.equal(propertyAfter.rentalPrice, 50)
                  assert.equal(propertyBefore.depositAmount, 10)
                  assert.equal(propertyAfter.depositAmount, 30)
                  assert.equal(propertyBefore.hashesOfPhotos.toString(), propertyAfter.hashesOfPhotos.toString())
                  assert.equal(propertyBefore.hashOfTermsAndConditions.toString(), propertyAfter.hashOfTermsAndConditions.toString())
              })
          })
          describe("removePropertyFromList", function () {
              it("removes property from list", async function () {
                  const id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      0,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  const listedPropertiesBefore = await mainContract.getListedPropertiesIds()
                  assert.equal(listedPropertiesBefore.toString().includes(id), true)
                  await mainContract.removePropertyFromList(id)
                  const listedPropertiesAfter = await mainContract.getListedPropertiesIds()
                  assert.equal(listedPropertiesAfter.toString().includes(id), false)
              })
              it("emits event after remove", async function () {
                  const id = await mainContract.getNumberOfProperties()
                  await mainContract.createProperty(
                      "ipfs://bafyreifm7zw33fcmjt7qdt74lugaphvzsft7rth6ufx6aeqrd7occob4au/metadata.json",
                      "Ben",
                      "QmedPszJ62ha2PnB11ngpmEhUSy2Td19Sgcp6NKbxx6AgE"
                  )
                  const rentalTerm = 60 * 60 * 24 * 30 //month
                  await mainContract.listProperty(
                      "nice flat with a lot of amenities",
                      0,
                      rentalTerm,
                      30,
                      10,
                      ["mockPhotoHash1", "mockPhotoHash2"],
                      "mockHashOfTermsAndconditions"
                  )
                  await expect(mainContract.removePropertyFromList(id)).to.emit(mainContract, "PropertyRemovedFromList")
              })
          })
          describe("createRentContract", function () {
              let id
              const rentalTerm = 60 * 60 * 24 * 30 //month
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
              })
              it("reverts if owner tries to rent a property that he owns", async function () {
                  await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = tenantManager.getTokenId(deployer.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  await expect(
                      mainContract.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  ).to.be.revertedWith("MainContract__OwnerCantBeTenant")
              })
              it("reverts if not related token owner tries to create a rent contract", async function () {
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenant1TokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const tenantManagerUser2Connected = await ethers.getContract("TenantManager", user2)
                  await tenantManagerUser2Connected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "Ben")
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUser2Connected = await ethers.getContract("MainContract", user2)
                  await expect(
                      mainContractUser2Connected.createRentContract(id, tenant1TokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  ).to.be.revertedWith("MainContract__NotOwner")
              })
              it("adds contract id to array of property contracts ids and array of tenant contracts", async function () {
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  const contractId = await mainContract.getNumberOfContracts()
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const arrayOfTenantContractsIds = await mainContract.getTenantContractsIds(tenantTokenId)
                  assert.equal(arrayOfPropertyContractsIds.toString().includes(contractId), true)
                  assert.equal(arrayOfTenantContractsIds.toString().includes(contractId), true)
              })
              it("emits event after creating contract", async function () {
                  const tenantManagerUserConnected = await ethers.getContract("TenantManager", user)
                  await tenantManagerUserConnected.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  const tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await expect(
                      mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
                  ).to.emit(mainContract, "RentContractCreated")
              })
          })
          describe("acceptRentContract", function () {
              let id, tenantTokenId

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
                  tenantTokenId = await tenantManagerUserConnected.getTokenId(user.address)
                  const currentTimestamp = new Date().getTime()
                  const validityTerm = currentTimestamp + 60 * 60 * 24 * 3 //3 days
                  const startTimestamp = currentTimestamp + 60 * 60 * 24 * 5
                  const mainContractUserConnected = await ethers.getContract("MainContract", user)
                  await mainContractUserConnected.createRentContract(id, tenantTokenId, rentalTerm, 30, 10, startTimestamp, validityTerm)
              })
              it("updates property data correctly", async function () {
                  const propertyBefore = await mainContract.getProperty(id)
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  const propertyAfter = await mainContract.getProperty(id)
                  assert.equal(Number(propertyBefore.rentContractsAccepted) + 1, propertyAfter.rentContractsAccepted)
                  assert.equal(propertyAfter.rentContractId.toString(), contractId.toString())
                  assert.equal(propertyAfter.isRented, true)
              })
              it("adds rent contract to property rent history array", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  const rentHistory = await mainContract.getPropertyRentHistory(id)
                  const rentContract = await mainContract.getRentContract(contractId)
                  assert.equal(rentHistory.toString().includes(rentContract), true)
              })
              it("assigns rent contract to tenant current contract adds rent contract to tenant rent history", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  const rentHistory = await mainContract.getTenantRentHistory(tenantTokenId)
                  const rentContract = await mainContract.getRentContract(contractId)
                  const currentContractId = await mainContract.getTenantCurrentContractId(tenantTokenId)
                  assert.equal(rentHistory.toString().includes(rentContract), true)
                  assert.equal(Number(currentContractId), Number(contractId))
              })
              it("updates rent contract data correctly", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  const rentContractBefore = await mainContract.getRentContract(contractId)
                  await mainContract.acceptRentContract(id, contractId)
                  const rentContractAfter = await mainContract.getRentContract(contractId)
                  assert.equal(rentContractBefore.status, 0)
                  assert.equal(rentContractAfter.status, 1)
                  assert.equal(
                      Number(rentContractAfter.expiryTimestamp),
                      Number(rentContractAfter.startTimestamp) + Number(rentContractAfter.rentalTerm)
                  )
              })
              it("removes property from listed properties", async function () {
                  const listedPropertiesBefore = await mainContract.getListedPropertiesIds()

                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await mainContract.acceptRentContract(id, contractId)
                  const listedPropertiesAfter = await mainContract.getListedPropertiesIds()
                  assert.equal(listedPropertiesAfter.toString().includes(id), false)
                  assert.equal(listedPropertiesBefore.toString().includes(id), true)
              })
              it("emits event after accepting rent contract", async function () {
                  const arrayOfPropertyContractsIds = await mainContract.getPropertyContractsIds(id)
                  const contractId = arrayOfPropertyContractsIds[0]
                  await expect(mainContract.acceptRentContract(id, contractId)).to.emit(mainContract, "RentContractConfirmed")
              })
          })
          describe("terminateRentContract", function () {
              it("reverts if function is called not by owner or tenant", async function () {})
              it("updates rent contract status and resets property current rent contract and tenant current rent contract", async function () {})
              it("creates a dispute", async function () {})
          })
          describe("cancelRentApplication", function () {})
          describe("getETHAmountInUSD", function () {})
      })
