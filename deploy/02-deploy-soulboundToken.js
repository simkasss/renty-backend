const { network, getNamedAccounts, deployments } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const { uploadSbtToStorage } = require("../utils/uploadToStorage")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = []
    const tenantSoulboundToken = await deploy("TenantSoulboundToken", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (!developmentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
        log("Verifying...")
        await verify(soulboundToken.address, args)
    }

    // const result = await uploadSbtToStorage("name")
    // console.log(result) //returns TokenURI. We need this URI to mint NFT
}
module.exports.tags = ["sbt"]
