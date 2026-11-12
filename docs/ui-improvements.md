# UI improvements: research and plan

Sources read: ethereum.org "7 heuristics for Web3 interface design", Clay "Core principles of Web3 website design", Coinbound "Web3 UX design patterns that build trust", 925 Studios breakdowns of Phantom and Stripe, DesignPixil "Fintech dashboard design guide", UXHero on WCAG in fintech.

## What the research says

1. Feedback follows action: every step visible, waiting time explained, transaction links to the explorer (ethereum.org).
2. The one number that matters comes first, in tabular figures, with a freshness stamp (DesignPixil).
3. Say what happened and what to do next in errors; never "Something went wrong" alone (Stripe).
4. Empty states teach the next action (Stripe).
5. Status must never rely on colour alone: icon or text too (WCAG 1.4.1).
6. Show the wallet, its token balance and the active network near the main action (ethereum.org, Clay).
7. Show people as recognisable identities (avatars), not bare hex (Phantom, Coinbound).
8. Restate amount and recipient before an irreversible step (DesignPixil, Coinbound).
9. Explain why a button is disabled with text, tied to the field (WCAG 3.3).

## Already in the apps

- One dominant number per app, tabular figures, explorer links on every step, status chips with text labels, empty states with a next action, chain banner with a switch button.

## Done in this round

| # | Improvement | Why |
|---|---|---|
| 1 | Toast for every transaction: sent, confirmed (with "View" explorer link), reverted | Feedback follows action |
| 2 | A reverted transaction is no longer treated as success | Correctness (the receipt status is checked now) |
| 3 | Errors say what happened and what to do, and show the contract's own reason when there is one | Stripe-style microcopy |
| 4 | "Live ... synced Ns ago" freshness stamp on the main card | Freshness stamps |
| 5 | Address avatars (a stable colour per address) with a "you" tag, on bounties, deals and campaigns | Identity |
| 6 | Wallet chip in the desktop top bar: avatar, address, USDC balance, network | Wallet and balance near the action |
| 7 | Page title, description, share preview text and favicon | Professional shell, better link previews |

## Done in the second round

| # | Improvement | Why |
|---|---|---|
| 8 | "You are about to..." line above each main button (Escrow, Bounty, Crowdfund start, pledge) restating amount and recipient | Restate before an irreversible step |
| 9 | "Still needed: ..." text above a disabled button | WCAG 3.3, clear next step |
| 10 | Icon next to every status chip | Status never by colour alone |
| 11 | Tabs fade and lift in | Polish |
| 12 | Wallet balance chip on phones (under the app switch) | Wallet and balance near the action |
| 14 | Pending card above the lists while a new deal, bounty or campaign confirms, with an explorer link | Feedback follows action |
| 15 | Releasing or returning escrow funds asks to confirm, restating amount and recipient | Irreversible step |

## Still open

| # | Improvement | Notes |
|---|---|---|
| 13 | Share preview image (1200x630 PNG) | Needs a designed image; the page already has title and description tags |

## Not planned

- Notifications by email or Telegram: needs a backend.
- Speed up or cancel stuck transactions: needs raw nonce handling that wallets already offer.
