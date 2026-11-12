export type BountyStatus = 0 | 1 | 2 // Open, Claimed, Cancelled
export type BountyType = 0 | 1 | 2 // Traditional, Contest, Cooperative

export interface Bounty {
  id: bigint
  creator: `0x${string}`
  title: string
  description: string
  reward: bigint
  status: BountyStatus
  claimer: `0x${string}`
  tags: string
  deadline: bigint
  acceptanceCriteria: string
  bountyType: BountyType
  estimatedHours: bigint
}

export interface Submission {
  submitter: `0x${string}`
  submissionNote: string
  timestamp: bigint
}

export type TxRecord = { hash: `0x${string}`; type: string; time: number; detail: string }

export const STATUS_LABEL: Record<BountyStatus, string> = { 0: 'Open', 1: 'Claimed', 2: 'Cancelled' }
export const TYPE_LABEL: Record<BountyType, string> = { 0: 'Traditional', 1: 'Contest', 2: 'Cooperative' }
export const TYPE_DESC: Record<BountyType, string> = {
  0: 'One winner gets the full reward',
  1: 'Creator picks the best submission as winner',
  2: 'Creator picks one winner (split payout coming soon)',
}
export const TYPE_NOTE: Record<BountyType, string | null> = {
  0: null,
  1: null,
  2: 'Note: Current contract pays one winner. Multi-split coming in v2.',
}

export const TAG_OPTIONS = ['design', 'development', 'content', 'marketing', 'research', 'bug', 'other']
export const CHAIN_ID = 5042002
export const APP_URL = typeof window !== 'undefined' && !window.location.hostname.includes('studio.arc.io') && !window.location.hostname.includes('e2b.app')
  ? window.location.origin
  : 'https://gleaming-twilight-94b805.netlify.app'
export const CONTRACT_ADDRESS = '0x8de137da25631defc4c990b46042daa8ba859fa3' as `0x${string}`
export const USDC_ADDRESS = '0x3600000000000000000000000000000000000000' as `0x${string}`

export function shortenAddr(addr: string) { return addr.slice(0, 6) + '...' + addr.slice(-4) }
export function fmtUsdc(raw: bigint) { return (Number(raw) / 1_000_000).toFixed(2) }
export function fmtDeadline(ts: bigint) {
  if (ts === 0n) return 'No deadline'
  const d = new Date(Number(ts) * 1000)
  const diff = d.getTime() - Date.now()
  if (diff < 0) return 'Expired'
  const days = Math.floor(diff / 86400000)
  const hrs = Math.floor((diff % 86400000) / 3600000)
  if (days > 0) return `${days}d ${hrs}h left`
  return `${hrs}h left`
}
export function parseErr(e: unknown): string {
  const msg = (e as { message?: string })?.message?.toLowerCase() ?? ''
  if (msg.includes('user rejected') || msg.includes('denied')) return 'Cancelled.'
  if (msg.includes('insufficient') || msg.includes('exceeds balance')) return 'Insufficient USDC balance.'
  if (msg.includes('already submitted')) return 'You already submitted to this bounty.'
  if (msg.includes('deadline passed')) return 'Bounty deadline has passed.'
  if (msg.includes('not open')) return 'Bounty is no longer open.'
  if (msg.includes('cannot receive usdc')) return 'Winner address cannot receive USDC.'
  if (msg.includes('reverted')) return 'Transaction failed on-chain.'
  return 'Something went wrong. Please try again.'
}
