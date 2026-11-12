import { useCallback, useMemo, useState } from 'react'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle, Briefcase, Search } from 'lucide-react'
import { CHAIN_ID, usd } from '@/escrowTypes'
import { BOUNTY_ABI } from '@/bountyAbi'
import { CONTRACT_ADDRESS, TAG_OPTIONS } from '@/bountyTypes'
import type { Bounty, Submission } from '@/bountyTypes'
import { SPECTRAL, c, display, glass } from '@/escrow/theme'
import { BountyCard } from './BountyCard'
import { PostBountyForm } from './PostBountyForm'
import { useNow } from './useNow'
import { HeroCard } from '@/ui/HeroCard'

type Tab = 'browse' | 'post' | 'mine'

export default function BountyApp() {
  const { address, chainId, isConnected } = useAccount()
  const { switchChain } = useSwitchChain()
  const [tab, setTab] = useState<Tab>('browse')
  const [search, setSearch] = useState('')
  const [tag, setTag] = useState('')
  const [onlyOpen, setOnlyOpen] = useState(true)
  const [sort, setSort] = useState<'new' | 'reward'>('new')
  const wrongChain = isConnected && chainId !== CHAIN_ID

  const { data: raw, refetch: refetchBounties, isLoading } = useReadContract({
    address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'getBounties', chainId: CHAIN_ID,
    query: { refetchInterval: 15000 },
  })
  const bounties = useMemo(() => (raw ?? []) as readonly Bounty[], [raw])
  const { data: subRes, refetch: refetchSubs } = useReadContracts({
    contracts: bounties.map((b) => ({ address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'getSubmissions', args: [b.id], chainId: CHAIN_ID }) as const),
    query: { enabled: bounties.length > 0, refetchInterval: 15000 },
  })
  const refresh = useCallback(() => { void refetchBounties(); void refetchSubs() }, [refetchBounties, refetchSubs])
  const onPosted = useCallback(() => { refresh(); setTab('browse'); setOnlyOpen(true); setSort('new') }, [refresh])

  const nowSec = useNow()
  const items = bounties.map((b, i) => {
    const r = subRes?.[i]
    const subs: readonly Submission[] = r && r.status === 'success' ? (r.result) : []
    const expired = b.deadline > 0n && BigInt(nowSec) > b.deadline
    return { b, subs, live: b.status === 0 && !expired }
  })
  const meL = address?.toLowerCase()
  const live = items.filter((i) => i.live)
  const pool = live.reduce((sum, i) => sum + i.b.reward, 0n)
  const mine = items.filter((i) => i.b.creator.toLowerCase() === meL)
  const needsReview = mine.filter((i) => i.live && i.subs.length > 0).length

  const q = search.trim().toLowerCase()
  const shown = items
    .filter((i) => (onlyOpen ? i.live : true))
    .filter((i) => !tag || i.b.tags.toLowerCase().split(',').map((t) => t.trim()).includes(tag))
    .filter((i) => !q || i.b.title.toLowerCase().includes(q) || i.b.description.toLowerCase().includes(q))
    .sort((a, z) => (sort === 'reward' ? Number(z.b.reward - a.b.reward) : Number(z.b.id - a.b.id)))

  const empty = (title: string, body: string, cta?: boolean) => (
    <div className="rounded-3xl p-8 text-center" style={glass.card}>
      <Briefcase className="mx-auto mb-2 size-7" style={{ color: c.subtle }} />
      <p className="text-sm font-semibold" style={{ color: c.ink }}>{title}</p>
      <p className="mx-auto mt-1 max-w-xs text-xs text-pretty" style={{ color: c.muted }}>{body}</p>
      {cta && <button onClick={() => setTab('post')} className="mt-4 min-h-11 rounded-2xl px-5 text-sm font-semibold text-white" style={{ background: c.accent }}>Post a bounty</button>}
    </div>
  )

  return (
    <div className="min-h-dvh" style={{ fontFamily: "'DM Sans', sans-serif" }}>
      <div className="h-1 w-full" style={{ background: SPECTRAL }} />
      <main className="mx-auto max-w-md space-y-4 px-4 py-6">
        <header className="flex items-center justify-between">
          <div>
            <h1 className="text-lg font-bold text-balance" style={{ ...display, color: c.ink }}>Bounty Board</h1>
            <p className="text-xs" style={{ color: c.muted }}>Post a task, pay the best work in USDC</p>
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
          label="Open rewards now"
          amount={isLoading ? '--' : usd(pool)}
          caption={isLoading ? 'Loading from Arc Testnet' : `${live.length} open ${live.length === 1 ? 'bounty' : 'bounties'} on Arc Testnet`}
          refreshLabel="Refresh bounties"
          onRefresh={refresh}
        />

        <nav className="flex gap-1 rounded-2xl p-1" style={glass.card} aria-label="Sections">
          {([['browse', 'Browse'], ['post', 'Post'], ['mine', 'My bounties']] as const).map(([id, label]) => (
            <button key={id} onClick={() => setTab(id)} aria-current={tab === id} className="relative min-h-10 flex-1 rounded-xl text-sm font-semibold transition-colors"
              style={tab === id ? { background: c.accent, color: '#fff' } : { color: c.muted }}>
              {label}
              {id === 'mine' && needsReview > 0 && <span className="absolute -right-0.5 -top-1 flex size-4 items-center justify-center rounded-full text-[10px] font-bold text-white" style={{ background: c.danger }}>{needsReview}</span>}
            </button>
          ))}
        </nav>

        {tab === 'post' && <PostBountyForm onCreated={onPosted} />}

        {tab === 'browse' && (
          <section className="space-y-3">
            <div className="space-y-2 rounded-3xl p-3.5" style={glass.card}>
              <label className="flex items-center gap-2 rounded-2xl px-3 py-2.5" style={glass.inner}>
                <Search className="size-4 shrink-0" style={{ color: c.subtle }} />
                <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search bounties" className="w-full bg-transparent text-sm outline-none placeholder:text-slate-400" style={{ color: c.ink }} />
              </label>
              <div className="flex flex-wrap gap-1.5">
                <button onClick={() => setOnlyOpen((v) => !v)} className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={onlyOpen ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>Open only</button>
                <button onClick={() => setSort((s) => (s === 'new' ? 'reward' : 'new'))} className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={{ color: c.muted, ...glass.inner }}>{sort === 'new' ? 'Newest' : 'Highest reward'}</button>
                {TAG_OPTIONS.map((t) => (
                  <button key={t} onClick={() => setTag(tag === t ? '' : t)} className="min-h-9 rounded-xl px-3 text-xs font-semibold capitalize" style={tag === t ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>{t}</button>
                ))}
              </div>
            </div>
            {isLoading ? <div className="h-28 animate-pulse rounded-3xl" style={glass.card} />
              : shown.length === 0 ? (bounties.length === 0
                ? empty('No bounties yet', 'Post the first one: set a USDC reward and let people compete for it.', true)
                : empty('Nothing matches', 'Try a different search or turn off Open only.'))
              : shown.map((i) => <BountyCard key={i.b.id.toString()} bounty={i.b} subs={i.subs} me={address} onChanged={refresh} />)}
          </section>
        )}

        {tab === 'mine' && (
          <section className="space-y-3">
            {!isConnected ? (
              <div className="rounded-3xl p-8 text-center" style={glass.card}>
                <p className="text-sm font-semibold" style={{ color: c.ink }}>Connect a wallet</p>
                <div className="mt-4 flex justify-center"><ConnectKitButton /></div>
              </div>
            ) : mine.length === 0 ? empty('You have not posted a bounty yet', 'Bounties you post show up here, with their submissions.', true)
              : [...mine].reverse().map((i) => <BountyCard key={i.b.id.toString()} bounty={i.b} subs={i.subs} me={address} onChanged={refresh} />)}
          </section>
        )}
      </main>
    </div>
  )
}
