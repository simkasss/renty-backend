const { ethers, network } = require("hardhat")
require("dotenv").config()
const fs = require("fs")

const frontEndContractsFile = "../rentdapp-frontend/constants/networkMapping.json"
const frontEndAbiLocation = "../rentdapp-frontend/constants/"

module.exports = async () => {
    if (process.env.UPDATE_FRONT_END) {
        console.log("Loading addresses and abi to the front end directory...")
        await updateContractAddresses()
        await updateAbi()
        console.log("Loaded to the front end directory.")
    }
}

async function updateAbi() {
    const mainContract = await ethers.getContract("MainContract")
    fs.writeFileSync(`${frontEndAbiLocation}MainContract.json`, mainContract.interface.format(ethers.utils.FormatTypes.json))

    const propertyNft = await ethers.getContract("PropertyNft")
    fs.writeFileSync(`${frontEndAbiLocation}PropertyNft.json`, propertyNft.interface.format(ethers.utils.FormatTypes.json))

    const tenantManager = await ethers.getContract("TenantManager")
    fs.writeFileSync(`${frontEndAbiLocation}TenantManager.json`, tenantManager.interface.format(ethers.utils.FormatTypes.json))

    const transfersAndDisputes = await ethers.getContract("TransfersAndDisputes")
    fs.writeFileSync(`${frontEndAbiLocation}TransfersAndDisputes.json`, transfersAndDisputes.interface.format(ethers.utils.FormatTypes.json))
}

async function updateContractAddresses() {
    const chainId = network.config.chainId.toString()
    const mainContract = await ethers.getContract("MainContract")
    const tenantManager = await ethers.getContract("TenantManager")
    const transfersAndDisputes = await ethers.getContract("TransfersAndDisputes")

    const contractAddresses = JSON.parse(fs.readFileSync(frontEndContractsFile, "utf8"))
    if (chainId in contractAddresses) {
        if (!contractAddresses[chainId]["MainContract"].includes(mainContract.address)) {
            contractAddresses[chainId]["MainContract"].push(mainContract.address)
        }
        if (!contractAddresses[chainId]["TenantManager"].includes(tenantManager.address)) {
            contractAddresses[chainId]["TenantManager"].push(tenantManager.address)
        }
        if (!contractAddresses[chainId]["TransfersAndDisputes"].includes(transfersAndDisputes.address)) {
            contractAddresses[chainId]["TransfersAndDisputes"].push(transfersAndDisputes.address)
        }
    } else {
        contractAddresses[chainId] = {
            MainContract: [mainContract.address],
            TenantManager: [tenantManager.address],
            TransfersAndDisputes: [transfersAndDisputes.address],
        }
    }

    fs.writeFileSync(frontEndContractsFile, JSON.stringify(contractAddresses))
}
module.exports.tags = ["all", "frontend"]
