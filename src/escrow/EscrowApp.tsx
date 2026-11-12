import { useCallback, useMemo, useState } from 'react'
import { MotionConfig } from 'framer-motion'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle, Handshake, ExternalLink } from 'lucide-react'
import { buildAddressExplorerUrl } from '@/onchain-facts'
import { ESCROW_ABI } from '@/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS, STATUS, ZERO, short, usd } from '@/escrowTypes'
import type { Deal } from '@/escrowTypes'
import { DealCard } from './DealCard'
import { Guide } from './Guide'
import { NewDealForm } from './NewDealForm'
import { SPECTRAL, c, display, glass } from './theme'
import { HeroCard } from '@/ui/HeroCard'

type Tab = 'deals' | 'new'
type Filter = 'active' | 'done'

const isActive = (s: number) => s <= STATUS.Delivered || s === STATUS.Disputed

/** Reads ?deal=<id> once so a shared link opens that deal directly. */
function readLinkedId(): bigint | null {
  const v = new URLSearchParams(window.location.search).get('deal')
  return v && /^\d{1,9}$/.test(v) ? BigInt(v) : null
}

export default function EscrowApp() {
  const { address, chainId, isConnected } = useAccount()
  const { switchChain } = useSwitchChain()
  const [tab, setTab] = useState<Tab>('deals')
  const [filter, setFilter] = useState<Filter>('active')
  const [linkedId] = useState(readLinkedId)
  const wrongChain = isConnected && chainId !== CHAIN_ID

  const { data: ids, refetch: refetchIds, isLoading: idsLoading } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'dealsOf', args: [address ?? ZERO],
    chainId: CHAIN_ID, query: { enabled: !!address, refetchInterval: 15000 },
  })
  const idList = useMemo(() => [...(ids ?? [])].reverse(), [ids])
  const { data: results, refetch: refetchDeals } = useReadContracts({
    contracts: idList.map((id) => ({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'getDeal', args: [id], chainId: CHAIN_ID }) as const),
    query: { enabled: idList.length > 0, refetchInterval: 15000 },
  })
  const { data: linked, refetch: refetchLinked, isLoading: linkedLoading, isError: linkedError } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'getDeal', args: [linkedId ?? 0n],
    chainId: CHAIN_ID, query: { enabled: linkedId !== null, refetchInterval: 15000, retry: false },
  })

  const refresh = useCallback(() => { void refetchIds(); void refetchDeals(); void refetchLinked() }, [refetchIds, refetchDeals, refetchLinked])
  const onCreated = useCallback(() => { refresh(); setTab('deals'); setFilter('active') }, [refresh])

  const deals: Deal[] = (results ?? []).flatMap((r) => (r.status === 'success' ? [r.result] : []))
  const active = deals.filter((d) => isActive(d.status))
  const shown = (filter === 'active' ? active : deals.filter((d) => !isActive(d.status))).filter((d) => d.id !== linkedId)
  const me = address?.toLowerCase()
  const locked = active.filter((d) => d.buyer.toLowerCase() === me).reduce((s, d) => s + d.amount, 0n)
  const incoming = active.filter((d) => d.seller.toLowerCase() === me).reduce((s, d) => s + d.amount, 0n)

  return (
    <MotionConfig reducedMotion="user">
      <div className="relative min-h-dvh overflow-hidden" style={{ fontFamily: "'DM Sans', sans-serif" }}>
        <div className="relative z-10 h-1 w-full" style={{ background: SPECTRAL }} />
        <main className="relative z-10 mx-auto max-w-md space-y-4 px-4 py-6">
          <header className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="flex size-9 items-center justify-center rounded-xl" style={{ background: c.accent }}>
                <Handshake className="size-5 text-white" />
              </div>
              <div>
                <h1 className="text-lg font-bold text-balance" style={{ ...display, color: c.ink }}>Escrow</h1>
                <p className="text-xs" style={{ color: c.muted }}>USDC held until both sides agree</p>
              </div>
            </div>
            <ConnectKitButton />
          </header>

          {wrongChain && (
            <div className="flex items-center gap-3 rounded-2xl px-4 py-3" style={{ background: 'rgba(192,57,43,0.08)', border: '1px solid rgba(192,57,43,0.2)' }}>
              <AlertTriangle className="size-4 shrink-0" style={{ color: c.danger }} />
              <p className="text-sm" style={{ color: c.danger }}>Switch to Arc Testnet to continue.</p>
              <button onClick={() => switchChain({ chainId: CHAIN_ID })} className="ml-auto min-h-9 rounded-xl px-3 text-xs font-semibold text-white" style={{ background: c.danger }}>Switch</button>
            </div>
          )}

          <HeroCard
            label="Held in escrow for you"
            amount={isConnected ? usd(locked + incoming) : '--'}
            caption={isConnected ? 'Across your active deals' : 'Connect your wallet to see your deals'}
            refreshLabel="Refresh deals"
            onRefresh={refresh}
          >
            {isConnected && (
              <div className="grid grid-cols-2 gap-2">
                <div className="rounded-2xl p-3" style={glass.inner}>
                  <p className="text-[11px]" style={{ color: c.muted }}>You locked</p>
                  <p className="text-base font-semibold tabular-nums" style={{ ...display, color: c.ink }}>{usd(locked)}</p>
                </div>
                <div className="rounded-2xl p-3" style={glass.inner}>
                  <p className="text-[11px]" style={{ color: c.muted }}>Coming to you</p>
                  <p className="text-base font-semibold tabular-nums" style={{ ...display, color: c.success }}>{usd(incoming)}</p>
                </div>
              </div>
            )}
          </HeroCard>

          <Guide />

          <nav className="flex gap-1 rounded-2xl p-1" style={glass.card} aria-label="Sections">
            {([['deals', 'My deals'], ['new', 'New deal']] as const).map(([id, label]) => (
              <button key={id} onClick={() => setTab(id)} aria-current={tab === id}
                className="min-h-11 flex-1 rounded-xl text-sm font-semibold transition-colors"
                style={tab === id ? { background: c.accent, color: '#fff' } : { color: c.muted }}>
                {label}
              </button>
            ))}
          </nav>

          {tab === 'new' && <NewDealForm onCreated={onCreated} />}

          {tab === 'deals' && (
            <section className="space-y-3">
              {linkedId !== null && (
                <div className="space-y-2">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Shared with you</p>
                  {linkedLoading ? (
                    <div className="h-28 animate-pulse rounded-3xl" style={glass.card} />
                  ) : linkedError || !linked ? (
                    <div className="rounded-3xl p-5 text-sm" style={{ ...glass.card, color: c.muted }}>Deal #{linkedId.toString()} was not found on Arc Testnet.</div>
                  ) : (
                    <>
                      <DealCard deal={linked} me={address} onChanged={refresh} defaultOpen />
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
                {([['active', `Active (${active.length})`], ['done', 'Finished']] as const).map(([id, label]) => (
                  <button key={id} onClick={() => setFilter(id)}
                    className="min-h-10 rounded-xl px-3.5 text-xs font-semibold"
                    style={filter === id ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>
                    {label}
                  </button>
                ))}
              </div>
              {!isConnected ? (
                <div className="rounded-3xl p-8 text-center" style={glass.card}>
                  <p className="text-sm font-semibold" style={{ color: c.ink }}>Connect a wallet to start</p>
                  <p className="mx-auto mt-1 max-w-xs text-xs text-pretty" style={{ color: c.muted }}>Your deals as buyer, seller or arbiter show up here.</p>
                  <div className="mt-4 flex justify-center"><ConnectKitButton /></div>
                </div>
              ) : idsLoading ? (
                <div className="h-28 animate-pulse rounded-3xl" style={glass.card} />
              ) : shown.length === 0 ? (
                <div className="rounded-3xl p-8 text-center" style={glass.card}>
                  <p className="text-sm font-semibold" style={{ color: c.ink }}>{filter === 'active' ? 'No active deals yet' : 'No finished deals yet'}</p>
                  <p className="mx-auto mt-1 max-w-xs text-xs text-pretty" style={{ color: c.muted }}>
                    {filter === 'active' ? 'Create a deal and lock USDC. It is released only when you approve.' : 'Released, refunded and resolved deals appear here.'}
                  </p>
                  {filter === 'active' && (
                    <button onClick={() => setTab('new')} className="mt-4 min-h-11 rounded-2xl px-5 text-sm font-semibold text-white" style={{ background: c.accent }}>Create a deal</button>
                  )}
                </div>
              ) : (
                shown.map((d, i) => <DealCard key={d.id.toString()} deal={d} me={address} onChanged={refresh} index={i} />)
              )}
            </section>
          )}

          <footer className="pb-4 text-center">
            <a href={buildAddressExplorerUrl(CHAIN_ID, ESCROW_ADDRESS)} target="_blank" rel="noopener noreferrer"
              className="inline-flex items-center gap-1 text-xs tabular-nums" style={{ color: c.subtle }}>
              Contract {short(ESCROW_ADDRESS)}<ExternalLink className="size-3" />
            </a>
          </footer>
        </main>
      </div>
    </MotionConfig>
  )
}
