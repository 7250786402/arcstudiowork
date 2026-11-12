import { getUsdc } from '@/onchain-facts'
import { Amount, usdcDecimalsFor } from '@/onchain-money'

export const CHAIN_ID = 5042002
export const ESCROW_ADDRESS = import.meta.env.VITE_ESCROW_ADDRESS as `0x${string}`
export const USDC_ADDRESS = (getUsdc(CHAIN_ID)?.address ?? '0x0000000000000000000000000000000000000000') as `0x${string}`

export type Addr = `0x${string}`
export const ZERO: Addr = '0x0000000000000000000000000000000000000000'

export interface Deal {
  id: bigint
  buyer: Addr
  seller: Addr
  sellerPayout: Addr
  arbiter: Addr
  amount: bigint
  title: string
  terms: string
  deliverBy: bigint
  reviewWindow: bigint
  deliveredAt: bigint
  disputedAt: bigint
  status: number
}

export const STATUS = {
  Funded: 0,
  Accepted: 1,
  Delivered: 2,
  Released: 3,
  Refunded: 4,
  Disputed: 5,
  Resolved: 6,
} as const

export const STATUS_LABEL: Record<number, string> = {
  0: 'Waiting for seller',
  1: 'In progress',
  2: 'Delivered',
  3: 'Released',
  4: 'Refunded',
  5: 'In dispute',
  6: 'Resolved',
}

export const DAY = 86400

export function short(a: string) {
  return a.slice(0, 6) + '...' + a.slice(-4)
}

export function usd(raw: bigint) {
  return Amount.fromRaw(raw, usdcDecimalsFor(CHAIN_ID)).toFixed(2)
}

export function fmtDate(ts: bigint) {
  return new Date(Number(ts) * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
}

export function parseErr(e: unknown): string {
  const msg = ((e as { message?: string })?.message ?? '').toLowerCase()
  if (msg.includes('user rejected') || msg.includes('denied')) return 'Cancelled in wallet.'
  if (msg.includes('insufficient') || msg.includes('exceeds balance')) return 'Not enough USDC.'
  if (msg.includes('deadline passed')) return 'The delivery deadline has passed.'
  if (msg.includes('reverted')) return 'The contract rejected this step. Refresh and check the deal status.'
  return 'Something went wrong. Please try again.'
}
