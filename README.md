The frontend repo: **https://github.com/simkasss/renty-frontend**

## Inspiration
The traditional real estate rental market faces a lack of transparency and security, rental processes are lengthy and complex, global accessibility is usually limited, disputes and fraudulent activities are persistent issues. Decentralized real estate rental platform Renty eliminates or reduces these issues, **making renting more transparent, convenient, and efficient** for both tenants and landlords.

## What it does
Renty is a decentralized real estate rental platform, that offers full rental management for tenants and landlords - from searching for a property to signing and managing rent contracts. After connecting using Metamask, landlords can create a property - meantime a property NFT is automatically minted. Landlords can list properties for rent, screen rent applications, review applying tenants' rent history, sign rent contracts, and manage them via the platform. Tenants can search for rental properties, review property data and rental terms, and after connecting and creating tenant soulbound token, tenants can apply for rent. After the landlord accepts a rent application - a rent contract is automatically signed. Main rental processes are executed using a platform - transferring and releasing deposit, paying rent, terminating rent contracts, managing disputes, withdrawing proceeds and so on. All of these processes are tracked and stored on the blockchain and both tenant and landlord can review payment history, rent contract disputes, see each other contact details, and other main rent contract information. 

## How I built it
The backend of the platform is built using **Solidity** and **Hardhat** and the frontend is built using **React** and **Next.js**. User Interface is built using **Material UI**.
There are four smart contracts: 
**TenantManager.sol** for minting Tenant Soulbound Tokens for each tenant;
**PropertyNft.sol** for minting NFTs for each created property;
**TransfersAndDisputes.sol** for managing all platform transactions and disputes of rent contracts;
**MainContract.sol** for creating and managing properties, rent applications, rent contracts and interacting with other contracts;
Property NFTs are stored on **NFT.Storage**.  Soulbound Tokens, property metadata, photos, and terms and conditions document are stored on **IPFS** and pinned using **PINATA**. 
For converting ETH/USD **Chainlink Data Feeds** are used.

