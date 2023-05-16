const { network, getNamedAccounts, deployments } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const propertyNft = await ethers.getContract("PropertyNft")
    const tenantSoulboundToken = await ethers.getContract("TenantSoulboundToken")

    const args = [propertyNft.address, tenantSoulboundToken.address, "0x694AA1769357215DE4FAC081bf1f309aDC325306"] // propertyNftContractAddress and tenantSoulboundContractAddress
    const rentApp = await deploy("RentApp", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (!developmentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
        log("Verifying...")
        await verify(rentApp.address, args)
    }
}
module.exports.tags = ["all", "rentApp"]
