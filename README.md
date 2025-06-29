# Wildid - Wildlife NFT Registry

A blockchain-based wildlife conservation platform that creates verifiable digital identities for endangered species through NFTs, enabling transparent tracking, protection, and funding of conservation efforts.

## Features

- **Species Registration**: Register endangered species with comprehensive metadata
- **Wildlife NFT Minting**: Create unique digital tokens for individual animals
- **Conservation Tracking**: Real-time tracking data and health status updates
- **Guardian System**: Verified conservationists manage and protect wildlife assets
- **Transfer Restrictions**: Automatic protection for highly endangered species
- **Conservation Funding**: Direct donations and transparent fund management
- **Marketplace**: Trade wildlife NFTs with built-in commission system

## Core Functions

### Admin Functions

```clarity
(set-administrator user status)
(verify-conservationist user)
(verify-species species-id)
(set-mint-price new-price)
(withdraw-conservation-funds amount recipient)
(freeze-metadata species-id)
```

### Conservation Functions

```clarity
(register-species name scientific-name habitat conservation-status population-estimate threat-level region)
(mint-wildlife-nft species-id individual-id tracking-data recipient)
(update-tracking-data token-id new-tracking-data health-status)
(donate-to-conservation species-id amount)
```

### Marketplace Functions

```clarity
(list-in-market token-id price comm-trait)
(unlist-in-market token-id)
(buy-in-market token-id comm-trait)
(transfer token-id sender recipient)
```

### Read-Only Functions

```clarity
(get-species-info species-id)
(get-token-metadata token-id)
(get-conservation-fund)
(get-mint-price)
(is-verified-conservationist user)
(get-species-funding species-id)
(get-donation-total donor)
```

## Usage Guide

### 1. Getting Verified as a Conservationist

Before you can register species or mint NFTs, you need verification:

```clarity
;; Admin verifies conservationist
(contract-call? .wildid verify-conservationist 'SP1EXAMPLE...)
```

### 2. Registering a New Species

Verified conservationists can register endangered species:

```clarity
(contract-call? .wildid register-species 
    u"Amur Leopard" 
    u"Panthera pardus orientalis"
    u"Temperate forests of Far East Russia and Northeast China"
    u"Critically Endangered"
    u120  ;; population estimate
    u9    ;; threat level (1-10)
    u"Far East Russia")
```

### 3. Admin Verification of Species

Administrators must verify registered species:

```clarity
(contract-call? .wildid verify-species u1)
```

### 4. Minting Wildlife NFTs

Once species are verified, conservationists can mint individual wildlife NFTs:

```clarity
(contract-call? .wildid mint-wildlife-nft 
    u1  ;; species-id
    u"AL-001"  ;; individual identifier
    u"GPS:45.123,-131.456;Last seen hunting near river;Weight:45kg"
    'SP1RECIPIENT...)
```

### 5. Updating Tracking Data

Guardians can update wildlife tracking information:

```clarity
(contract-call? .wildid update-tracking-data 
    u1  ;; token-id
    u"GPS:45.234,-131.567;Healthy;New territory established"
    u"healthy")
```

### 6. Conservation Donations

Anyone can donate to species conservation:

```clarity
(contract-call? .wildid donate-to-conservation u1 u5000000)  ;; 5 STX
```

### 7. Marketplace Trading

List wildlife NFT for sale:

```clarity
(contract-call? .wildid list-in-market u1 u10000000 commission-trait)
```

Buy from marketplace:

```clarity
(contract-call? .wildid buy-in-market u1 commission-trait)
```

## Data Structures

### Species Registry
- Name and scientific classification
- Habitat and geographic region
- Conservation status and threat level
- Population estimates
- Verification status and metadata locking

### Token Metadata
- Species linkage and individual identification
- Real-time tracking data and location
- Health status monitoring
- Guardian assignment and permissions
- Transfer restrictions for protection
- Conservation contribution tracking

### Guardian Permissions
- Transfer authorization levels
- Tracking data update rights
- Verification levels and registration dates

## Conservation Impact

- **Transparency**: All conservation funds and activities are recorded on-chain
- **Accountability**: Verified conservationists ensure data integrity
- **Protection**: High threat-level species automatically get transfer restrictions
- **Funding**: Direct species-specific donations with transparent allocation
- **Tracking**: Real-time wildlife monitoring and health status updates

## Security Features

- Multi-level verification system for conservationists and species
- Transfer restrictions for critically endangered species (threat level ≥ 7)
- Metadata freezing to prevent tampering with verified data
- Administrative controls for fund withdrawal and system management
- Guardian permission system for tracking data updates

## Error Codes

- `u100`: Owner only function
- `u101`: Not token owner
- `u102`: Listing not found
- `u103`: Wrong commission trait
- `u104`: Token/species not found
- `u105`: Metadata frozen
- `u106`: Mint limit exceeded
- `u107`: Transfer restricted
- `u108`: Insufficient funds
- `u109`: Invalid conservation status
- `u110`: User not verified

## Installation

1. Clone the repository
2. Install Clarinet: `npm install -g @hirosystems/clarinet`
3. Run tests: `clarinet test`
4. Deploy: `clarinet deploy`

## Contributing

This project supports global wildlife conservation efforts. Contributions should focus on:
- Enhanced tracking mechanisms
- Improved verification systems
- Additional conservation metrics
- Integration with real-world conservation databases

## License

Open source conservation technology for protecting endangered species worldwide.
