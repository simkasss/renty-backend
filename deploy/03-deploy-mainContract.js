const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const propertyNft = await ethers.getContract("PropertyNft")
    const tenantManager = await ethers.getContract("TenantManager")

    const args = [propertyNft.address, tenantManager.address, "0x694AA1769357215DE4FAC081bf1f309aDC325306"]
    const mainContract = await deploy("MainContract", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(mainContract.address, args)
    }
}
module.exports.tags = ["all", "mainContract"]
