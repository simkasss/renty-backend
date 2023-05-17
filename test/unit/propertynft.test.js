const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("PropertyNFT Unit Tests", function () {
          let deployer, propertyNft, user

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              propertyNft = await ethers.getContract("PropertyNft")
          })
          describe("constructor", function () {
              it("initializes correctly", async function () {
                  const tokenCounter = await propertyNft.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "0")
              })
          })
          describe("mintNft", function () {
              it("allows to mint and updates counter correctly", async function () {
                  const txResponse = await propertyNft.mintNft(
                      deployer.address,
                      "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json"
                  )
                  await txResponse.wait(1)
                  const tokenCounter = await propertyNft.getTokenCounter()
                  assert.equal(tokenCounter.toString(), "1")
              })
              it("emits event after minting", async function () {
                  await expect(
                      propertyNft.mintNft(deployer.address, "ipfs://bafyreiblprd6vxh62izwsruinwj5jcekl7vrpkrfr4kbrldd2mw4ydce3m/metadata.json")
                  ).to.emit(propertyNft, "NftMinted")
              })
          })
      })
