# Testing roadmap

Goal: know that Bounty Board, Escrow and Crowdfund work before more people use them. Testnet only.

## Where we are

| Layer | What it proves | Status |
|---|---|---|
| Contract unit, fuzz and invariant tests (Foundry) | The contract logic is right in isolation | Done: 293 pass (Escrow 101, Crowdfund 94, Bounty Board 98) |
| Live-chain tests on a fork of Arc Testnet (real USDC) | The deployed contracts behave the same with real USDC | Done: Escrow 41, Bounty Board 26, Crowdfund 22 (+1 skipped, unreachable guard). Each passed 3 runs in a row |
| Browser and wallet test | The screens, wallet pop-ups and confirmations work | Needs a person with a wallet: checklist below |

## Part A: automated, already run

1. A fork test of every function of the three contracts against real USDC, with the same addresses the app uses.
2. Each script passed 3 runs in a row and fails loudly (non-zero exit) if anything fails or if it ends without a summary line.
3. Re-run any time:
   - `cd /home/user/app && bun run /home/user/fork-tests/EscrowDeal.integration.test.ts`
   - `cd /home/user/app && bun run /home/user/fork-tests/BountyBoard.integration.test.ts`
   - `cd /home/user/app && bun run /home/user/fork-tests/Crowdfund.integration.test.ts`
   - `cd /home/user/fork-tests && ./run-3x.sh Crowdfund` runs one contract 3 times (use `BountyBoard` or `EscrowDeal` for the others).

## Part B: browser and wallet checklist (about 45 minutes)

Before you start:
- Make three MetaMask accounts: **A** (the main one), **B**, **C**.
- Give each some test USDC. Gas is paid in USDC, so keep at least 3 USDC in each.
- Use the preview for the newest version.
- Keep one note: for every step write PASS or the screenshot of what went wrong.

### B1. Bounty Board (10 min) - already passed once on 11 Nov
- [ ] A posts a 1 USDC bounty (Allow USDC, then Post). It shows in Browse and the coin tower gets a coin.
- [ ] B submits work. The card shows "1 submission".
- [ ] A picks B (the confirm bar appears, then confirm). A green tick animation plays.
- [ ] B's USDC balance goes up. The card shows "Awarded" and a payout link in Onchain activity.

### B2. Escrow, normal path (10 min)
- [ ] A creates a deal for B: 1 USDC, any title and terms, auto-release 1 day. The line "You are about to..." shows the right amount and address.
- [ ] A pending card shows while it confirms, then the deal appears with status Funded.
- [ ] B opens the deal and clicks Accept, then Mark as delivered.
- [ ] A clicks Release. A confirm panel asks "Release the payment?" with amount and address. Confirm.
- [ ] Anyone clicks Withdraw. B receives 1 USDC.
- [ ] The Timeline lists every step with a time and a transaction link (the "accepted" step has no link, on purpose).

### B3. Escrow, dispute path (10 min)
- [ ] A creates a deal for B with C as arbiter.
- [ ] B accepts and delivers. A raises a dispute.
- [ ] C resolves with a 50/50 split. Both A and B can claim their half.

### B4. Crowdfund, refund path (10 min, no waiting)
- [ ] A starts a campaign: goal 5 USDC, 1 hour.
- [ ] B pledges 2 USDC. The ring and the raised amount update.
- [ ] A cancels the campaign. B clicks refund and gets 2 USDC back.

### B5. Crowdfund, success path (needs a 1 hour wait)
- [ ] A starts a campaign: goal 3 USDC, 1 hour. B pledges 3 USDC.
- [ ] After one hour anyone clicks "Send ... to the campaign wallet". The campaign wallet receives 3 USDC.

### B6. Quick checks (5 min)
- [ ] Phone width: nothing overlaps, buttons are easy to tap.
- [ ] Wrong network: switch the wallet to another network. A red banner offers "Switch".
- [ ] Reject a transaction in MetaMask. The message says it was cancelled and nothing was sent.

## Part C: after the tests

- Send the assistant the notes. It reads the transaction and console logs itself, so you do not need to copy errors.
- Every FAIL gets fixed and the same step is tested again.
- When B1 to B6 all pass, update the post, and then share the link widely.

## Known limits (not test failures)

- Bounty Board: one spam submission blocks a creator from cancelling a bounty that has no deadline. A creator can submit to their own bounty.
- Escrow: the "seller accepted" step has no onchain event, so the timeline shows it without a link.
- The fork tests prove the contracts, not the screens. Part B is the only thing that tests the screens and wallet pop-ups.
