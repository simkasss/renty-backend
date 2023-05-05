const { network, getNamedAccounts, deployments } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = ["0xc25b01a423aA49883bC8d62e0a67915AB198E645", "0x24C9FE3317575bf4E7A2DD79643D2dF11caBF273"] // propertyNftContractAddress and tenantSoulboundContractAddress
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
module.exports.tags = ["rentApp"]
