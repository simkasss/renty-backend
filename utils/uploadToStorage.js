/* NFT.Storage is a service that allows creators to store their non-fungible tokens (NFTs) 
on decentralized file storage networks such as IPFS (InterPlanetary File System) and Filecoin.
   To store an NFT on NFT.Storage:
1. Use NFT.Storage API to upload the NFT file to IPFS 
2. Save the returned IPFS hash as the token URI.*/
// Import the NFTStorage class and File constructor from the 'nft.storage' package
const { NFTStorage, File } = require("nft.storage")
// The 'mime' npm package helps us set the correct file type on our File objects
const mime = require("mime")
const fs = require("fs")
const path = require("path")
const fetch = (...args) => import("node-fetch").then(({ default: fetch }) => fetch(...args))

require("dotenv").config()
const NFTSTORAGE_API_KEY = process.env.NFTSTORAGE_API_KEY

//SOURCE: https://nft.storage/docs/how-to/mint-erc-1155/

async function uploadPropertyNftToStorage(name, address, countryCode) {
    // create a new NFTStorage client using API key
    const nftstorage = new NFTStorage({ token: NFTSTORAGE_API_KEY })
    const image = await fileFromPath("utils/house.jpeg")

    // call client.store, passing in the metadata
    const nft = {
        name,
        description: "NFT that represents a property",
        image,
        address,
        countryCode,
        // Custom - if LT, tai registrų centro objekto numeris
    }
    const metadata = await nftstorage.store(nft)
    console.log("NFT data stored! Metadata URI: ", metadata.url)

    return metadata.url //returns TokenURI (ipfs://)
}
async function uploadSbtToStorage(name) {
    // create a new NFTStorage client using API key
    const nftstorage = new NFTStorage({ token: NFTSTORAGE_API_KEY })
    const image = await fileFromPath("utils/tenant.jpeg")
    // call client.store, passing in the metadata
    const nft = {
        name,
        description: "Soulbound Token that represents a tenant",
        image,
    }
    const metadata = await nftstorage.store(nft)
    console.log("Soulbound token data stored! Metadata URI: ", metadata.url)
    return metadata.url //returns TokenURI (ipfs://)
}
// A helper read a file from a location on disk and return a File object.
async function fileFromPath(filePath) {
    const content = await fs.promises.readFile(filePath)
    const type = mime.getType(filePath)
    return new File([content], path.basename(filePath), { type })
}

// For example's sake, we'll fetch an image from an HTTP URL.
async function getExampleImage() {
    const imageOriginUrl = "https://user-images.githubusercontent.com/87873179/144324736-3f09a98e-f5aa-4199-a874-13583bf31951.jpg"
    const r = await fetch(imageOriginUrl)
    if (!r.ok) {
        throw new Error(`error fetching image: [${r.statusCode}]: ${r.status}`)
    }
    return r.blob()
}

module.exports = {
    uploadPropertyNftToStorage,
    uploadSbtToStorage,
}
