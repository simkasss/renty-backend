const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const mainContract = await ethers.getContract("MainContract")
    const tenantManager = await ethers.getContract("TenantManager")

    const args = [mainContract.address, tenantManager.address] // propertyNftContractAddress and tenantSoulboundContractAddress
    const transfersAndDisputes = await deploy("TransfersAndDisputes", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(transfersAndDisputes.address, args)
    }
}
module.exports.tags = ["all", "transfersAndDisputes"]
