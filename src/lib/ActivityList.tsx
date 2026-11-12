import { Check, ExternalLink } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID } from '@/escrowTypes'
import { c } from '@/escrow/theme'

export interface ActivityItem {
  key: string
  label: string
  detail?: string
  hash: `0x${string}`
  /** Unix seconds */
  timestamp?: number
}

interface Props {
  title?: string
  items: ActivityItem[]
  loading?: boolean
  error?: boolean
}

/** A list of onchain steps, each with its time and a link to the transaction on the explorer. */
export function ActivityList({ title = 'Onchain activity', items, loading, error }: Props) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>{title}</p>
      {loading ? (
        <div className="mt-2 h-10 animate-pulse rounded-xl" style={{ background: 'rgba(18,45,69,0.06)' }} />
      ) : error ? (
        <p className="mt-2 text-xs" style={{ color: c.muted }}>Could not load onchain history right now.</p>
      ) : items.length === 0 ? (
        <p className="mt-2 text-xs" style={{ color: c.muted }}>No onchain events found yet.</p>
      ) : (
        <ol className="mt-2 space-y-3">
          {items.map((item) => (
            <li key={item.key} className="flex gap-3">
              <div className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full" style={{ background: c.accent }}>
                <Check className="size-3 text-white" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium" style={{ color: c.ink }}>{item.label}</p>
                {item.detail && <p className="break-words text-xs tabular-nums" style={{ color: c.muted }}>{item.detail}</p>}
                <div className="flex items-center gap-2 text-[11px]" style={{ color: c.subtle }}>
                  {item.timestamp !== undefined && (
                    <span>{new Date(item.timestamp * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })}</span>
                  )}
                  <a href={buildTxExplorerUrl(CHAIN_ID, item.hash)} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-0.5 underline">
                    View transaction<ExternalLink className="size-2.5" />
                  </a>
                </div>
              </div>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}
