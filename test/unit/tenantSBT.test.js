const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { JsonRpcProvider } = require("@ethersproject/providers")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("TenantSoulboundToken Unit Tests", function () {
          let deployer, tenantSoulboundToken

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
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
              beforeEach(async function () {
                  const txResponse = await tenantSoulboundToken.mintSBT()
                  await txResponse.wait(1)
              })
              it("allows to mint and updates counter correctly", async function () {
                  const tokenCounter = await tenantSoulboundToken.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "1")
              })
          })
      })
