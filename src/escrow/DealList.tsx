import { useReadContract } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { ESCROW_ABI } from '@/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS } from '@/escrowTypes'
import type { Addr, Deal } from '@/escrowTypes'
import { Button } from '@/ui/Button'
import { EmptyState } from '@/ui/EmptyState'
import { Skeleton } from '@/ui/Skeleton'
import { DealCard } from './DealCard'
import { c, glass } from './theme'

export type Filter = 'active' | 'done'

interface DealListProps {
  address?: Addr
  isConnected: boolean
  loading: boolean
  filter: Filter
  onFilter: (f: Filter) => void
  activeCount: number
  shown: Deal[]
  fresh: ReadonlySet<string>
  linkedId: bigint | null
  onChanged: () => void
  onCreate: () => void
}

/** The "My deals" tab: an optional shared deal on top, then the user's deals. */
export function DealList({ address, isConnected, loading, filter, onFilter, activeCount, shown, fresh, linkedId, onChanged, onCreate }: DealListProps) {
  const { data: linked, refetch, isLoading: linkedLoading, isError: linkedError } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'getDeal', args: [linkedId ?? 0n],
    chainId: CHAIN_ID, query: { enabled: linkedId !== null, refetchInterval: 15000, retry: false },
  })
  const changed = () => { onChanged(); void refetch() }

  return (
    <section className="space-y-3">
      {linkedId !== null && (
        <div className="space-y-2">
          <p className="text-[11px] font-semibold uppercase tracking-[0.1em]" style={{ color: c.muted }}>Shared with you</p>
          {linkedLoading ? (
            <Skeleton className="h-28 rounded-3xl" />
          ) : linkedError || !linked ? (
            <div className="rounded-3xl p-5 text-sm" style={{ ...glass.card, color: c.muted }}>Deal #{linkedId.toString()} was not found on Arc Testnet.</div>
          ) : (
            <>
              <DealCard deal={linked} me={address} onChanged={changed} defaultOpen />
              {!isConnected && (
                <div className="flex items-center justify-between gap-3 rounded-2xl p-3.5" style={glass.inner}>
                  <p className="text-xs text-pretty" style={{ color: c.muted }}>Connect the wallet named in this deal to accept or act on it.</p>
                  <ConnectKitButton />
                </div>
              )}
            </>
          )}
        </div>
      )}

      <div className="flex gap-1.5">
        {([['active', `Active (${activeCount})`], ['done', 'Finished']] as const).map(([id, label]) => (
          <button key={id} onClick={() => onFilter(id)} className="btn min-h-11 rounded-xl px-3.5 text-xs font-semibold"
            style={filter === id ? { background: c.accent, color: c.onAccent } : { color: c.muted, ...glass.inner }}>
            {label}
          </button>
        ))}
      </div>

      {!isConnected ? (
        <EmptyState kind="wallet" title="Connect a wallet to start" body="Your deals as buyer, seller or arbiter show up here." action={<ConnectKitButton />} />
      ) : loading ? (
        <div className="space-y-3">{[0, 1].map((n) => <Skeleton key={n} className="h-32 rounded-3xl" />)}</div>
      ) : shown.length === 0 ? (
        <EmptyState
          kind="escrow"
          title={filter === 'active' ? 'No active deals yet' : 'No finished deals yet'}
          body={filter === 'active' ? 'Create a deal and lock USDC. It is released only when you approve.' : 'Released, refunded and resolved deals appear here.'}
          action={filter === 'active' ? <Button onClick={onCreate}>Create a deal</Button> : undefined}
        />
      ) : (
        shown.map((d, i) => (
          <div key={d.id.toString()} className={fresh.has(d.id.toString()) ? 'fresh-glow' : undefined}>
            <DealCard deal={d} me={address} onChanged={changed} index={i} />
          </div>
        ))
      )}
    </section>
  )
}
