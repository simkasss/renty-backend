const { network, getNamedAccounts, deployments } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const { uploadToStorage } = require("../utils/uploadToStorage")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = []
    const soulboundToken = await deploy("SoulboundToken", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    if (!developmentChains.includes(network.name) && process.env.POLYGONSCAN_API_KEY) {
        log("Verifying...")
        await verify(soulboundToken.address, args)
    }

    // const result = await uploadToStorage("utils/house.jpeg", "name", "address")
    // console.log(result) //returns TokenURI. We need this URI to mint NFT
}
module.exports.tags = ["nft"]
