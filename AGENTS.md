# USDC Tip Jar + USDC Raffle

> Built with Arc Studio - money-powered apps in minutes

This is the **project memory** - what Arc Studio remembers about building this app. It helps future agents (or humans) understand and extend the project.

---

## What This App Does

A simple USDC Tip Jar app on Arc Testnet. Users connect their wallet and send USDC tips to a recipient address. Features quick-amount chips ($1, $5, $10, $25), a custom amount input, an optional note field, live USDC balance display, transaction confirmation with explorer link, and chain-switch handling.

## Raffle Contract

- Contract: USDCRaffle
- Address: 0x3ff9c7a155445c7c74693b9d916d9aa001150d4d
- Chain: Arc Testnet (Chain ID: 5042002)
- Owner: 0x5B12Ce46C7194aD57d143bC22847224047b1Ef42 (platform deployer wallet)
- Winner selection: commit-reveal scheme (owner commits keccak256(secret) on-chain, then reveals secret to pick winner)
- Refund window: 3 days after endTime if owner does not pick winner

## Tip Jar Important Setup

- **TIP_RECIPIENT** in `src/App.tsx` must be replaced with a real wallet address before use. Currently set to the zero address as a placeholder.
- Test USDC is available via the Arc Studio sidebar "Get test USDC" button.

## Design

- Arc Light mode, consumer glass aesthetic
- Fonts: Space Grotesk (display), DM Sans (body)
- Spectral strip accent on the main card
- Chain: Arc Testnet (Chain ID: 5042002)
- USDC ERC-20 address: 0x3600000000000000000000000000000000000000

## Tech Stack

- Frontend: React 18, Vite, TypeScript, Tailwind CSS
- Web3: wagmi v2, viem v2, ConnectKit
- Contracts: Solidity 0.8.28 + Foundry. Sources in `contracts/`, unit tests in `contracts/test/*.t.sol`. Build with `bun run contracts:build` (`forge build`), test with `bun run contracts:test` (`forge test`).
- Wallet: injected (MetaMask, etc.)
- Chain: Arc Testnet (Chain ID: 5042002, imported from `viem/chains`)
- Token: USDC (6 decimals) (Address: 0x3600000000000000000000000000000000000000, Chain: Arc Testnet)
- Toasts: Sonner

## Current app: Escrow (USDC escrow between buyer and seller)

- Contract: `contracts/EscrowDeal.sol`, deployed on Arc Testnet at `0xf22ec72e96a6c71c32b44740f8cc182cc6d2ed58` (also in `.env` as `VITE_ESCROW_ADDRESS`).
- Every deal needs an arbiter or an auto-release window. The seller names a payout address on accept and can update it. Seller payouts are pull-based.
- UI: `src/App.tsx` (shell), `src/escrow/` (NewDealForm, DealCard, DealActions, useTxFlow, theme), `src/escrowTypes.ts`, `src/escrowAbi.ts`.
- Earlier contracts still deployed: USDCRaffle, PredictionGame, BountyBoard (`0x8de137da25631defc4c990b46042daa8ba859fa3`). Their ABIs and types remain in `src/` (raffleAbi, predictionAbi, bountyAbi, bountyTypes). Raffle and Prediction Game UIs were replaced by later apps and are not in the project.

## Three apps on one site

- `src/App.tsx` is only a switch between `src/bounty/BountyApp.tsx` (Bounty Board, default), `src/escrow/EscrowApp.tsx` and `src/crowdfund/CrowdfundApp.tsx`. `?app=escrow` or `?deal=ID` opens Escrow; `?app=crowdfund` opens Crowdfund.
- Crowdfund contract: `contracts/Crowdfund.sol`, deployed on Arc Testnet at `0x008a328ad702578c39d00517efa8b8abe6d05b39` (also in `.env` as `VITE_CROWDFUND_ADDRESS`). All or nothing: success is decided at the deadline; anyone can send raised funds to the beneficiary; backers refund if the campaign failed or was cancelled. Reviewed (clean) and Slither found only timestamp warnings; no unit tests written yet.
- The Bounty Board UI (`src/bounty/`) was rebuilt on 10 Nov 2026 against the existing BountyBoard contract after the earlier UI source was lost. It is a leaner version: browse, post, my bounties, submit, pick winner, cancel/reclaim, tip. The contract pays a single winner.

## Design notes

- Dark immersive look (Arc Dark): tokens and glass surfaces live in `src/escrow/theme.ts`; fonts (Space Grotesk, DM Sans) load from `index.html`. Text on the pale-blue accent uses `c.onAccent`.
- `src/ui/` is the shared kit: `AppShell` (two panels on desktop), `SummaryPanel` (the one big number plus a 3D visual), `Button`, `Tabs`, `Skeleton`, `EmptyState`, `Reveal`, `CountUp`, `Backdrop`.
- Each app has one signature visual driven by real data: `BountyPoolVisual` (coin per open bounty), `VaultVisual` (door shut while deals hold funds), `GoalVisual` and `GoalRing` (raised over goal). With no data they stay still.
- Motion is wrapped in `MotionConfig reducedMotion="user"` in `src/App.tsx`; CSS animations also stop under reduced motion (`src/index.css`).
- Avoid very long single file writes: split big components into smaller files.

- Contract tests (Foundry): `contracts/test/` has unit, fuzz and invariant tests for EscrowDeal (101), Crowdfund (94) and BountyBoard (98). Run `forge test`. A live-chain integration script for EscrowDeal is in `/home/user/fork-tests/` and was flaky (3 of 5 runs fully green).
- Known BountyBoard limits (from the tests): one spam submission blocks `cancelBounty`, and on a bounty with no deadline the creator cannot reclaim; a creator can submit to their own bounty and approve themselves, so the reputation counters are not trustworthy and the UI does not show them.

## Key Files

- `src/App.tsx` - App switch
- `src/bounty/` - Bounty Board UI
- `src/escrow/` - Escrow UI
- `src/config.ts` - wagmi config (chains, connectors, transports)

## To Run

```bash
bun install
bun run dev
```
