# Shroom Nation Dashboard API Setup

## Option 1: Alchemy (Recommended)
1. Go to https://www.alchemy.com/
2. Click "Get your API key"
3. Sign up for free account
4. Create new app for "Base Mainnet"
5. Copy the API key to `src/Env.elm` as `alchemyApiKey`
6. **COMPLETE**: API key added: `UF9iXc8OyKFMJHfd5p40k`

**Free Tier**: 100M compute units/month, 5 requests/second

## Option 2: Moralis (Alternative)
1. Go to https://moralis.io/
2. Sign up for free account
3. Get API key from dashboard
4. 40,000 requests/month free
5. **COMPLETE**: API key added to `src/Env.elm` as `moralisApiKey`

## Option 3: Public RPC (Zero Setup)
Using Alchemy's free public endpoint:
- RPC: `https://base-mainnet.g.alchemy.com/public`
- No API key needed
- Rate limited but functional

## Token Contract Address
**SHRMN (SHROOMnation) on Base**: `0xAD3eB8058e9E0ad547e2aF549388Df451b00D8BD`
- Contract updated in `src/Env.elm` as `shroomTokenAddress`
- Verified on BaseScan and DexScreener

## Required Token Holder API Calls
```javascript
// Get token holder count using Alchemy
POST https://base-mainnet.g.alchemy.com/v2/UF9iXc8OyKFMJHfd5p40k
{
  "method": "alchemy_getTokenMetadata",
  "params": ["0xAD3eB8058e9E0ad547e2aF549388Df451b00D8BD"]
}

// Get token holders using Alchemy
POST https://base-mainnet.g.alchemy.com/v2/UF9iXc8OyKFMJHfd5p40k  
{
  "method": "alchemy_getOwnersForToken",
  "params": ["0xAD3eB8058e9E0ad547e2aF549388Df451b00D8BD"]
}
```

## Update Frequency
- Alchemy updates data every ~5 minutes
- Free tier allows polling every 12 seconds
- Recommended: Poll every 1-2 minutes 