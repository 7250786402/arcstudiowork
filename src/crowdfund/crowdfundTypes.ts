import type { Addr } from '@/escrowTypes'

export const CROWDFUND_ADDRESS = import.meta.env.VITE_CROWDFUND_ADDRESS as Addr

export type Campaign = {
  id: bigint
  creator: Addr
  beneficiary: Addr
  title: string
  description: string
  goal: bigint
  deadline: bigint
  raised: bigint
  refunded: bigint
  withdrawn: boolean
  cancelled: boolean
}

// Matches the contract's Status enum order.
export const STATUS = { Active: 0, Succeeded: 1, Withdrawn: 2, Failed: 3, Cancelled: 4 } as const

export const STATUS_LABEL: Record<number, string> = {
  0: 'Live',
  1: 'Goal reached',
  2: 'Paid out',
  3: 'Not funded',
  4: 'Cancelled',
}

/** Percent funded with two decimals (can pass 100 when overfunded). */
export function percent(raised: bigint, goal: bigint): number {
  if (goal === 0n) return 0
  return Number((raised * 10000n) / goal) / 100
}

export function timeLeft(deadline: bigint, nowSec: number): string {
  const s = Number(deadline) - nowSec
  if (s <= 0) return 'Ended'
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  if (d > 0) return `${d}d ${h}h left`
  if (h > 0) return `${h}h ${m}m left`
  return `${Math.max(m, 1)}m left`
}
