import { useEffect } from 'react'
import { useWaitForTransactionReceipt } from 'wagmi'
import { ExternalLink, Loader2 } from 'lucide-react'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID } from '@/escrowTypes'
import { c, display, glass } from '@/escrow/theme'
import { removePending, usePending } from '@/lib/pending'
import type { PendingApp, PendingItem } from '@/lib/pending'

function PendingCard({ item }: { item: PendingItem }) {
  const { isSuccess, isError } = useWaitForTransactionReceipt({ hash: item.hash })
  const done = isSuccess || isError
  useEffect(() => {
    if (!done) return
    const id = window.setTimeout(() => removePending(item.hash), 2500)
    return () => window.clearTimeout(id)
  }, [done, item.hash])

  return (
    <div className="flex items-center gap-3 rounded-2xl p-3.5" style={{ ...glass.card, borderStyle: 'dashed' }} role="status">
      {done ? null : <Loader2 className="size-4 shrink-0 animate-spin" style={{ color: c.accent }} aria-hidden />}
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold" style={{ ...display, color: c.ink }}>{item.label}</p>
        <p className="text-xs" style={{ color: isError ? c.danger : c.muted }}>
          {isError ? 'Could not confirm this transaction. Check it on the explorer.' : isSuccess ? 'Confirmed. Updating the list...' : 'Pending: waiting for Arc Testnet to confirm'}
        </p>
      </div>
      <a href={buildTxExplorerUrl(CHAIN_ID, item.hash)} target="_blank" rel="noopener noreferrer" aria-label="View transaction on the explorer" className="btn flex size-11 shrink-0 items-center justify-center rounded-xl" style={glass.inner}>
        <ExternalLink className="size-4" style={{ color: c.muted }} />
      </a>
    </div>
  )
}

/** Transactions this browser has sent that are still waiting for a receipt, shown above the lists. */
export function PendingCards({ app }: { app: PendingApp }) {
  const items = usePending(app)
  if (items.length === 0) return null
  return <div className="space-y-2">{items.map((i) => <PendingCard key={i.hash} item={i} />)}</div>
}
