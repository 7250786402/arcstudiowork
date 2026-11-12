# USDC apps on Arc Testnet

Three small apps that use USDC on Arc Testnet: a **Bounty Board**, an **Escrow** and a **Crowdfund**. They run on testnet only and have not had a third-party audit.

Live demo: https://gleaming-twilight-94b805.netlify.app (you need Arc Testnet USDC to try it)

Built with [Arc Studio](https://studio.arc.io)

The site holds three apps, with a switch at the top:

- **Bounty Board:** post a task with a USDC reward, people submit work, and you pick the winner who gets paid. Filter by skill, search, and sort by reward. If a bounty has a deadline you can take your USDC back after it passes.
- **Escrow:** a buyer locks USDC for a deal, the seller accepts the terms, and the money is released only when both sides are satisfied. If they disagree or go quiet, an arbiter or an agreed auto-release time settles it, so funds never stay stuck. Open it directly with `?app=escrow`.
- **Crowdfund:** start a campaign with a USDC goal and a deadline. Backers pledge USDC. If the goal is reached, the money goes to the campaign wallet; if not, every backer can take their USDC back. Open it directly with `?app=crowdfund`.

## What you can do

- Create a deal: choose the seller, amount, terms and delivery deadline, then lock USDC.
- Accept a deal as the seller and choose where your payout goes.
- Mark work as delivered, release payment, or return the USDC.
- Raise a dispute and let an arbiter decide how the money is split.
- Collect payment automatically if the buyer stays silent past the agreed time.
- See your deals in one place, with live status and links to the block explorer.
- Share a deal with a link. The other person opens it, connects their wallet and sees the deal straight away.
- Follow each deal's timeline: every step with its time and a link to the transaction.
- Read a short guide on how escrow works the first time you open the app.

## Tech stack

React, Vite, TypeScript, Tailwind CSS, wagmi, viem, ConnectKit, Solidity with Foundry.

## Development

Prerequisites: [Bun](https://bun.sh) and [Foundry](https://getfoundry.sh).

```bash
bun install
bun run dev
```

Other commands:

```bash
bun run check            # lint and typecheck
bun run contracts:build  # compile contracts
bun run contracts:test   # run contract tests
```

### Environment variables

- `VITE_ESCROW_ADDRESS`: address of the deployed escrow contract on Arc Testnet.
- `VITE_CROWDFUND_ADDRESS`: address of the deployed crowdfund contract on Arc Testnet.
- `VITE_ESCROW_DEPLOY_BLOCK`: block number the escrow contract was deployed at. Deal timelines read events from this block onward.
