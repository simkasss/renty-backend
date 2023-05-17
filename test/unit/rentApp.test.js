const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("RentApp Unit Tests", function () {
          let deployer, rentApp, user

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              user = accounts[1]
              await deployments.fixture(["all"])
              rentApp = await ethers.getContract("RentApp")
          })
          //   describe("constructor", function () {
          //       it("initializes correctly", async function () {})
          //   })
          //   describe("mintPropertyNft", function () {
          //       it("allows to mint and updates variables correctly", async function () {})
          //       it("...", async function () {})
          //   })
      })
