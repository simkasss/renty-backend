const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("TenantSoulboundToken Unit Tests", function () {
          let deployer, tenantSoulboundToken, user

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              tenantSoulboundToken = await ethers.getContract("TenantSoulboundToken")
          })
          describe("constructor", function () {
              it("initializes correctly", async function () {
                  const tokenCounter = await tenantSoulboundToken.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "0")
              })
          })
          describe("mintSBT", function () {
              it("allows to mint and updates counter correctly", async function () {
                  const txResponse = await tenantSoulboundToken.mintSBT(
                      deployer.address,
                      "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                  )
                  await txResponse.wait(1)
                  const tokenCounter = await tenantSoulboundToken.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "1")
              })
              it("emits event after minting", async function () {
                  await expect(
                      tenantSoulboundToken.mintSBT(
                          deployer.address,
                          "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                      )
                  ).to.emit(tenantSoulboundToken, "SBTMinted")
              })
          })
          describe("burn", function () {
              it("lets owner burn token", async function () {
                  const txResponse = await tenantSoulboundToken.mintSBT(
                      deployer.address,
                      "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                  )
                  await txResponse.wait(1)
                  const tokenOwnerBeforeBurn = await tenantSoulboundToken.getTokenOwner(0)
                  const tx2Response = await tenantSoulboundToken.burn(0)
                  await tx2Response.wait(1)
                  const tokenOwnerAfterBurn = await tenantSoulboundToken.getTokenOwner(1)
                  assert.equal(tokenOwnerBeforeBurn, deployer.address)
                  assert.equal(tokenOwnerAfterBurn, "0x0000000000000000000000000000000000000000")
              })
              it("reverts when someone else tries to burn not owned token", async function () {
                  const txResponse = await tenantSoulboundToken.mintSBT(
                      deployer.address,
                      "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                  )
                  await txResponse.wait(1)
                  const otherTenantSoulboundToken = tenantSoulboundToken.connect(user)

                  await expect(otherTenantSoulboundToken.burn(0)).to.be.revertedWith("TenantSoulboundToken__NotOwner")
              })
          })
          describe("transfer", function () {
              it("doesn't let to transfer a token", async function () {
                  const txResponse = await tenantSoulboundToken.mintSBT(
                      deployer.address,
                      "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                  )
                  await txResponse.wait(1)
                  await expect(tenantSoulboundToken.transferFrom(deployer.address, user.address, 0)).to.be.revertedWith(
                      "TenantSoulboundToken__CantBeTransfered"
                  )
              })
          })
      })
