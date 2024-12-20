# NFT Marketplace Smart Contract

A comprehensive smart contract implementation for an NFT marketplace built on the Stacks blockchain. This contract enables NFT minting, trading, and cross-chain bridging with integrated royalty mechanisms and metadata management.

## Features

- NFT minting with customizable royalty rates
- NFT listing and trading functionality
- Cross-chain NFT bridging support
- Standardized metadata management
- Built-in marketplace fees
- Trade history tracking
- Performance metrics
- Royalty distribution system

## Core Functions

### NFT Management

- `mint-nft`: Create a new NFT with royalty settings and metadata
- `bridge-nft`: Import NFTs from other supported chains
- `update-metadata`: Modify NFT metadata (restricted to owner)

### Marketplace Operations

- `list-nft`: List an NFT for sale with a specified price
- `delist-nft`: Remove an NFT from the marketplace
- `buy-nft`: Purchase a listed NFT with automatic fee and royalty distribution

### Query Functions

- `get-metadata`: Retrieve NFT metadata
- `get-nft-info`: Get comprehensive NFT information
- `get-trade-history`: View trading history for an NFT
- `get-performance-metrics`: Access marketplace performance statistics

## Market Parameters

- Marketplace Fee: 5%
- Maximum Royalty Rate: 20%
- Maximum NFT ID: 999,999
- Supported Chains: Ethereum, Solana

## Data Structures

### NFT Metadata
```
{
    name: string-ascii (max 100 chars),
    description: string-ascii (max 500 chars),
    image-url: string-ascii (max 200 chars),
    attributes: list of traits (max 20)
}
```

### Market Listing
```
{
    price: uint,
    seller: principal,
    listed: bool
}
```

### Royalty Configuration
```
{
    creator: principal,
    royalty-rate: uint
}
```

## Error Codes

- `ERR-NOT-AUTHORIZED (u1)`: User not authorized for operation
- `ERR-INSUFFICIENT-BALANCE (u2)`: Insufficient funds for purchase
- `ERR-INVALID-ROYALTY (u3)`: Invalid royalty rate
- `ERR-NFT-NOT-FOUND (u4)`: NFT does not exist
- `ERR-INVALID-NFT-ID (u5)`: Invalid NFT ID format/range
- `ERR-INVALID-PRICE (u6)`: Invalid price setting
- `ERR-ALREADY-LISTED (u7)`: NFT already listed
- `ERR-INVALID-CHAIN (u8)`: Unsupported chain for bridging
- `ERR-INVALID-METADATA (u9)`: Invalid metadata format
- `ERR-NOT-LISTED (u10)`: NFT not listed for sale
- `ERR-INVALID-EXTERNAL-ID (u11)`: Invalid external NFT ID

## Security Features

- Ownership validation for all owner-restricted operations
- Input validation for all public functions
- Safe arithmetic operations
- Proper authorization checks
- Standardized error handling

## Performance Tracking

The contract maintains the following metrics:
- Total trading volume
- Total royalties distributed
- Total marketplace fees collected

## Usage Example

```clarity
;; Mint a new NFT
(contract-call? .nft-marketplace mint-nft 
    u1 
    u10 
    {
        name: "Example NFT",
        description: "This is an example NFT",
        image-url: "https://example.com/image.png",
        attributes: (list 
            {trait: "Background", value: "Blue"}
            {trait: "Character", value: "Robot"}
        )
    }
)

;; List NFT for sale
(contract-call? .nft-marketplace list-nft u1 u1000000)

;; Purchase NFT
(contract-call? .nft-marketplace buy-nft u1)
```