/* NFT.Storage is a service that allows creators to store their non-fungible tokens (NFTs) 
on decentralized file storage networks such as IPFS (InterPlanetary File System) and Filecoin.
   To store an NFT on NFT.Storage:
1. Use NFT.Storage API to upload the NFT file to IPFS 
2. Save the returned IPFS hash as the token URI.*/
const { NFTStorage } = require("nft.storage")
const fetch = (...args) => import("node-fetch").then(({ default: fetch }) => fetch(...args))
require("dotenv").config()
const NFTSTORAGE_API_KEY = process.env.NFTSTORAGE_API_KEY

//SOURCE: https://nft.storage/docs/how-to/mint-erc-1155/

async function uploadPropertyNftToStorage(name, address, countryCode) {
    // create a new NFTStorage client using API key
    const nftstorage = new NFTStorage({ token: NFTSTORAGE_API_KEY })
    // call client.store, passing in the metadata
    const nft = {
        name,
        address,
        countryCode,
        // Custom - if LT, tai registrų centro objekto numeris
    }
    const metadata = await nftstorage.store(nft)
    console.log("NFT data stored!")
    console.log("Metadata URI: ", metadata.url)
    return metadata.url //returns TokenURI (ipfs://)
}
async function uploadSbtToStorage(name) {
    // create a new NFTStorage client using API key
    const nftstorage = new NFTStorage({ token: NFTSTORAGE_API_KEY })
    // call client.store, passing in the metadata
    const nft = {
        name,
    }
    const metadata = await nftstorage.store(nft)
    console.log("Soulbound token data stored!")
    console.log("Metadata URI: ", metadata.url)
    return metadata.url //returns TokenURI (ipfs://)
}

module.exports = {
    uploadPropertyNftToStorage,
    uploadSbtToStorage,
}
