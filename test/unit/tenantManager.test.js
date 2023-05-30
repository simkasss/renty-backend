const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("TenantManager Unit Tests", function () {
          let deployer, tenantManager, user

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              tenantManager = await ethers.getContract("TenantManager")
          })
          describe("constructor", function () {
              it("initializes correctly", async function () {
                  const tokenCounter = await tenantManager.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "0")
              })
          })
          describe("mintSBT", function () {
              it("allows to mint and updates counter correctly", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)
                  const tokenCounter = await tenantManager.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "1")
              })
              it("emits event after minting", async function () {
                  await expect(
                      tenantManager.mintSBT(deployer.address, "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json")
                  ).to.emit(tenantManager, "SoulboundMinted")
              })
          })
          describe("burn", function () {
              it("lets owner burn token", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)
                  const tokenOwnerBeforeBurn = await tenantManager.getTokenOwner(0)
                  const tx2Response = await tenantManager.burn(0)
                  await tx2Response.wait(1)
                  const tokenOwnerAfterBurn = await tenantManager.getTokenOwner(1)
                  assert.equal(tokenOwnerBeforeBurn, deployer.address)
                  assert.equal(tokenOwnerAfterBurn, "0x0000000000000000000000000000000000000000")
              })
              it("reverts when someone else tries to burn not owned token", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)
                  const othertenantManager = tenantManager.connect(user)

                  await expect(othertenantManager.burn(0)).to.be.revertedWith("TenantManager__NotOwner")
              })
          })
          describe("transfer", function () {
              it("doesn't let to transfer a token", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)
                  await expect(tenantManager.transferFrom(deployer.address, user.address, 0)).to.be.revertedWith("TenantManager__CantBeTransfered")
              })
          })
          describe("getTokenCounter", function () {
              it("it gets token counter", async function () {
                  const tokenCounter = await tenantManager.getTokenCounter()
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)
                  const tokenCounter2 = await tenantManager.getTokenCounter()
                  assert.equal(tokenCounter, 0)
                  assert.equal(tokenCounter2, 1)
              })
          })
          describe("getTokenOwner", function () {
              it("it gets token owner", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)

                  const tokenOwner = await tenantManager.getTokenOwner(0)
                  assert.equal(tokenOwner, deployer.address)
              })
          })
          describe("getTokenId", function () {
              it("it gets owners token id", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)

                  const tokenId = await tenantManager.getTokenId(deployer.address)
                  assert.equal(tokenId, 0)
              })
          })
          describe("getTokenOwnerName", function () {
              it("it gets token owner name", async function () {
                  const mint = await tenantManager.mintSBT("ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json", "John")
                  await mint.wait(1)

                  const tokenOwner = await tenantManager.getTokenOwnerName(0)
                  assert.equal(tokenOwner, "John")
              })
          })
      })
