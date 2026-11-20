# How I verified three contracts on Arc Testnet with Foundry

Short, reproducible steps. I did this today for three contracts (a bounty board, an escrow and a crowdfund) that were already deployed to Arc Testnet.

I'm not a developer. I build these apps with Arc Studio, which is also where I'm sharing them from. The commands below are the ones I actually ran.

## What you need
- A contract already deployed on Arc Testnet (chain ID 5042002) and its address.
- The same source code and compiler settings the deployment was built from.
- Foundry (I used forge 1.7.1).
- No API key. The Arc Testnet explorer exposes a Blockscout-style API, so none was needed for me.

My `foundry.toml` settings, for reference:

```toml
solc_version = "0.8.28"
evm_version = "paris"
optimizer = true
optimizer_runs = 200
```

## Verify a contract with no constructor arguments

```bash
forge verify-contract <CONTRACT_ADDRESS> contracts/Crowdfund.sol:Crowdfund \
  --chain-id 5042002 \
  --verifier blockscout \
  --verifier-url https://explorer.testnet.arc.io/api/ \
  --watch
```

`--watch` keeps polling until the explorer answers. What I saw:

```
Submitted contract for verification:
	Response: `OK`
Contract verification status:
Details: `Pending in queue`
Contract verification status:
Details: `Pass - Verified`
Contract successfully verified
```

## Verify a contract that has a constructor argument
My bounty board takes one constructor argument, the owner address. Encode it and pass it in:

```bash
ARGS=$(cast abi-encode "constructor(address)" <OWNER_ADDRESS>)

forge verify-contract <CONTRACT_ADDRESS> contracts/BountyBoard.sol:BountyBoard \
  --constructor-args $ARGS \
  --chain-id 5042002 \
  --verifier blockscout \
  --verifier-url https://explorer.testnet.arc.io/api/ \
  --watch
```

Use the exact value that was passed at deployment.

## Check it worked
Open the contract on the explorer (`https://explorer.testnet.arc.io/address/<CONTRACT_ADDRESS>`). Before verifying, I saw no source for any of my three contracts. After, the source and ABI show up, and the compiler is listed as v0.8.28.

## Things to watch for
These are what I expect to matter, based on how verification works. I only hit the happy path, so treat them as a checklist, not as errors I reproduced:
- The source and compiler settings must match what produced the deployed bytecode. If you edit the contract after deploying, verification should fail until you rebuild from the deployed version.
- Constructor arguments must match exactly.
- If your project uses `lib/` or `node_modules` imports (I use OpenZeppelin), forge sends the flattened sources for you.

## Why bother
Anyone can now read the source for the address they are about to send USDC to. For a contract that holds funds, that is worth the two minutes.

My three verified contracts (Arc Testnet):
- Bounty Board: https://explorer.testnet.arc.io/address/0x529d7675ad15d92a236a52f86298c3b0b845d02e
- Escrow: https://explorer.testnet.arc.io/address/0x3addc8c4e5ca5f7e98a61ebc3c7232ef09cb3b6c
- Crowdfund: https://explorer.testnet.arc.io/address/0x008a328ad702578c39d00517efa8b8abe6d05b39

Code and tests: https://github.com/7250786402/arcstudiowork

Testnet only, and none of these contracts has had a third-party audit.
