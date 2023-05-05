const { ethers, network } = require("hardhat")
require("dotenv").config()
const fs = require("fs")

const frontEndContractsFile = "../rentdapp-frontend/constants/networkMapping.json"
//const frontEndAbiLocation = "../rentdapp-frontend/constants/"

module.exports = async () => {
    if (process.env.UPDATE_FRONT_END) {
        console.log("updating front end...")
        await updateContractAddresses()
        //await updateAbi()
        console.log("Frontend updated.")
    }
}

// async function updateAbi() {
//     const rentApp = await ethers.getContract("RentApp")
//     fs.writeFileSync(`${frontEndAbiLocation}RentApp.json`, rentApp.interface.format(ethers.utils.FormatTypes.json))

//     const propertyNft = await ethers.getContract("PropertyNft")
//     fs.writeFileSync(`${frontEndAbiLocation}PropertyNft.json`, propertyNft.interface.format(ethers.utils.FormatTypes.json))

//     const tenantSoulboundToken = await ethers.getContract("TenantSoulboundToken")
//     fs.writeFileSync(`${frontEndAbiLocation}TenantSoulboundToken.json`, tenantSoulboundToken.interface.format(ethers.utils.FormatTypes.json))
// }

async function updateContractAddresses() {
    const chainId = network.config.chainId.toString()
    const rentApp = await ethers.getContract("RentApp")
    const contractAddresses = JSON.parse(fs.readFileSync(frontEndContractsFile, "utf8"))
    if (chainId in contractAddresses) {
        if (!contractAddresses[chainId]["RentApp"].includes(rentApp.address)) {
            contractAddresses[chainId]["RentApp"].push(rentApp.address)
        }
    } else {
        contractAddresses[chainId] = { RentApp: [rentApp.address] }
    }
    fs.writeFileSync(frontEndContractsFile, JSON.stringify(contractAddresses))
}
module.exports.tags = ["all", "frontend"]
