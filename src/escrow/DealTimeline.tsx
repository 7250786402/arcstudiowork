import { Check, ExternalLink } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID, STATUS, usd } from '@/escrowTypes'
import type { Deal } from '@/escrowTypes'
import { c } from './theme'
import { useDealEvents } from './useDealEvents'

interface Item {
  key: string
  label: string
  detail?: string
  hash?: `0x${string}`
  block?: bigint
  timestamp?: number
  note?: string
}

const big = (v: unknown): bigint => (typeof v === 'bigint' ? v : 0n)

export function DealTimeline({ deal }: { deal: Deal }) {
  const { data: events, isLoading, isError } = useDealEvents()

  const items: Item[] = []
  for (const log of events ?? []) {
    if (big(log.args.id) !== deal.id || log.args.id === undefined) continue
    const base = { key: `${log.transactionHash}-${log.logIndex}`, hash: log.transactionHash, block: log.blockNumber, timestamp: log.timestamp }
    switch (log.eventName) {
      case 'DealCreated':
        items.push({ ...base, label: 'Deal created and funded', detail: `${usd(big(log.args.amount))} USDC locked` })
        break
      case 'Delivered':
        items.push({ ...base, label: 'Seller marked it delivered' })
        break
      case 'DisputeRaised':
        items.push({ ...base, label: 'Dispute raised' })
        break
      case 'DisputeResolved':
        items.push({ ...base, label: 'Arbiter decided', detail: `Seller ${usd(big(log.args.toSeller))}, buyer ${usd(big(log.args.toBuyer))} USDC` })
        break
      case 'Released':
        items.push({ ...base, label: 'Payment released to seller' })
        break
      case 'Refunded':
        items.push({ ...base, label: 'USDC returned to buyer' })
        break
      case 'PayoutUpdated':
        items.push({ ...base, label: 'Seller changed payout address' })
        break
      case 'SellerWithdrawn':
        items.push({ ...base, label: 'Seller withdrew payout', detail: `${usd(big(log.args.amount))} USDC` })
        break
    }
  }
  items.sort((a, b) => (a.block === b.block ? 0 : (a.block ?? 0n) < (b.block ?? 0n) ? -1 : 1))

  // Acceptance has no onchain event, so show it as a state-derived step without a transaction link.
  const accepted = deal.status !== STATUS.Funded && deal.status !== STATUS.Refunded
  if (accepted && items.length > 0) {
    items.splice(1, 0, { key: 'accepted', label: 'Seller accepted the terms', note: 'No transaction record for this step' })
  }

  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Timeline</p>
      {isLoading ? (
        <div className="mt-2 h-10 animate-pulse rounded-xl" style={{ background: 'rgba(255,255,255,0.06)' }} />
      ) : isError ? (
        <p className="mt-2 text-xs" style={{ color: c.muted }}>Could not load onchain history right now.</p>
      ) : items.length === 0 ? (
        <p className="mt-2 text-xs" style={{ color: c.muted }}>No events found for this deal yet.</p>
      ) : (
        <ol className="mt-2 space-y-3">
          {items.map((item, i) => (
            <li key={item.key} className="relative flex gap-3">
              {i < items.length - 1 && <span aria-hidden className="absolute left-[9px] top-6 -bottom-3 w-px" style={{ background: 'linear-gradient(180deg, rgba(172,198,233,0.45), rgba(172,198,233,0.08))' }} />}
              <div className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full" style={{ background: item.hash ? c.accent : 'rgba(255,255,255,0.12)', boxShadow: item.hash ? '0 0 0 3px rgba(172,198,233,0.16), 0 0 14px rgba(172,198,233,0.45)' : 'none' }}>
                <Check className="size-3" style={{ color: item.hash ? c.onAccent : c.muted }} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium" style={{ color: c.ink }}>{item.label}</p>
                {item.detail && <p className="text-xs tabular-nums" style={{ color: c.muted }}>{item.detail}</p>}
                <div className="flex items-center gap-2 text-[11px]" style={{ color: c.subtle }}>
                  {item.timestamp !== undefined && (
                    <span>{new Date(item.timestamp * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })}</span>
                  )}
                  {item.note && <span>{item.note}</span>}
                  {item.hash && (
                    <a href={buildTxExplorerUrl(CHAIN_ID, item.hash)} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-0.5 underline">
                      tx<ExternalLink className="size-2.5" />
                    </a>
                  )}
                </div>
              </div>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}
