import { asBig } from './useContractEvents'
import type { ChainEvent } from './useContractEvents'

/** One step of a running total: unix seconds and the total in USDC after that event. */
export interface SeriesPoint {
  t: number
  v: number
}

const MICRO = 1_000_000

/**
 * Turns contract events into a running USDC total. `delta` returns the signed change in raw 6-decimal units
 * for an event (0n to ignore it). Events without a block time are skipped.
 */
export function buildSeries(events: readonly ChainEvent[] | undefined, delta: (e: ChainEvent) => bigint): SeriesPoint[] {
  if (!events) return []
  const ordered = events
    .filter((e) => e.timestamp !== undefined)
    .sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0) || Number(a.blockNumber - b.blockNumber) || a.logIndex - b.logIndex)
  const out: SeriesPoint[] = []
  let total = 0n
  for (const e of ordered) {
    const d = delta(e)
    if (d === 0n) continue
    total += d
    if (total < 0n) total = 0n
    out.push({ t: e.timestamp ?? 0, v: Number(total) / MICRO })
  }
  return out
}

/** Bounty Board: USDC sitting in open bounties (posted minus paid out minus cancelled). */
export function bountyPoolSeries(events: readonly ChainEvent[] | undefined): SeriesPoint[] {
  const rewards = new Map<string, bigint>()
  for (const e of events ?? []) {
    if (e.eventName === 'BountyCreated') rewards.set(String(asBig(e.args.id)), asBig(e.args.reward) ?? 0n)
  }
  return buildSeries(events, (e) => {
    if (e.eventName === 'BountyCreated') return asBig(e.args.reward) ?? 0n
    if (e.eventName === 'BountyClaimed') return -(asBig(e.args.reward) ?? 0n)
    if (e.eventName === 'BountyCancelled') return -(rewards.get(String(asBig(e.args.id))) ?? 0n)
    return 0n
  })
}

/** Escrow: USDC locked in deals (funded minus released, refunded or resolved). */
export function escrowLockedSeries(events: readonly ChainEvent[] | undefined): SeriesPoint[] {
  return buildSeries(events, (e) => {
    if (e.eventName === 'DealCreated') return asBig(e.args.amount) ?? 0n
    if (e.eventName === 'Released' || e.eventName === 'Refunded') return -(asBig(e.args.amount) ?? 0n)
    if (e.eventName === 'DisputeResolved') return -((asBig(e.args.toSeller) ?? 0n) + (asBig(e.args.toBuyer) ?? 0n))
    return 0n
  })
}

/** Crowdfund: USDC held in campaigns (pledged minus refunded minus paid out). */
export function crowdfundHeldSeries(events: readonly ChainEvent[] | undefined): SeriesPoint[] {
  return buildSeries(events, (e) => {
    if (e.eventName === 'Pledged') return asBig(e.args.amount) ?? 0n
    if (e.eventName === 'Refunded' || e.eventName === 'FundsWithdrawn') return -(asBig(e.args.amount) ?? 0n)
    return 0n
  })
}
