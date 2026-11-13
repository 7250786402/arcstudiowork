import { useCallback, useMemo, useState } from 'react'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle, Search } from 'lucide-react'
import { CHAIN_ID, usd } from '@/escrowTypes'
import { BOUNTY_ABI } from '@/bountyAbi'
import { CONTRACT_ADDRESS, TAG_OPTIONS } from '@/bountyTypes'
import type { Bounty, Submission } from '@/bountyTypes'
import { c, display, glass } from '@/escrow/theme'
import { AppShell } from '@/ui/AppShell'
import { BountyPoolVisual } from '@/ui/BountyPoolVisual'
import { Button } from '@/ui/Button'
import { EmptyState } from '@/ui/EmptyState'
import { Reveal } from '@/ui/Reveal'
import { Skeleton } from '@/ui/Skeleton'
import { SummaryPanel } from '@/ui/SummaryPanel'
import { Tabs } from '@/ui/Tabs'
import { BountyCard } from './BountyCard'
import { PostBountyForm } from './PostBountyForm'
import { useNow } from './useNow'
import { useContractEvents } from '@/lib/useContractEvents'
import { bountyPoolSeries } from '@/lib/series'
import { BOUNTY_EVENTS_ABI } from '@/bountyEvents'
import { ActivityChart } from '@/ui/ActivityChart'
import { TabPanel } from '@/ui/TabPanel'
import { PendingCards } from '@/ui/PendingCards'
import { useFreshKeys } from '@/ui/useFreshKeys'

type Tab = 'browse' | 'post' | 'mine'

const chip = (on: boolean) => (on ? { background: c.accent, color: c.onAccent } : { color: c.muted, ...glass.inner })

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
  const events = useContractEvents({ key: 'bounty', address: CONTRACT_ADDRESS, abi: BOUNTY_EVENTS_ABI })
  const poolSeries = useMemo(() => bountyPoolSeries(events.data), [events.data])
  const fresh = useFreshKeys(bounties.map((b) => b.id.toString()), !isLoading)
  const items = bounties.map((b, i) => {
    const r = subRes?.[i]
    const subs: readonly Submission[] = r && r.status === 'success' ? (r.result) : []
    const expired = b.deadline > 0n && BigInt(nowSec) > b.deadline
    return { b, subs, live: b.status === 0 && !expired }
  })
  const meL = address?.toLowerCase()
  const live = items.filter((i) => i.live)
  const pool = live.reduce((sum, i) => sum + i.b.reward, 0n)
  const paidOut = items.filter((i) => i.b.status === 1).reduce((sum, i) => sum + i.b.reward, 0n)
  const mine = items.filter((i) => i.b.creator.toLowerCase() === meL)
  const needsReview = mine.filter((i) => i.live && i.subs.length > 0).length

  const q = search.trim().toLowerCase()
  const shown = items
    .filter((i) => (onlyOpen ? i.live : true))
    .filter((i) => !tag || i.b.tags.toLowerCase().split(',').map((t) => t.trim()).includes(tag))
    .filter((i) => !q || i.b.title.toLowerCase().includes(q) || i.b.description.toLowerCase().includes(q))
    .sort((a, z) => (sort === 'reward' ? Number(z.b.reward - a.b.reward) : Number(z.b.id - a.b.id)))

  const postCta = <Button onClick={() => setTab('post')}>Post a bounty</Button>
  const list = (rows: typeof items) => rows.map((i, n) => (
    <Reveal key={i.b.id.toString()} index={n} fresh={fresh.has(i.b.id.toString())}><BountyCard bounty={i.b} subs={i.subs} me={address} onChanged={refresh} /></Reveal>
  ))

  return (
    <AppShell
      side={
        <>
          <header className="flex items-center justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-xl font-bold text-balance" style={{ ...display, color: c.ink }}>Bounty Board</h1>
              <p className="text-sm text-pretty" style={{ color: c.muted }}>Post a task and lock the reward in USDC. Pay whoever delivers the best work.</p>
            </div>
            <ConnectKitButton />
          </header>
          <SummaryPanel
              chart={<ActivityChart title="Reward pool, all bounties" points={poolSeries} nowSec={nowSec} />}
            eyebrow="Open rewards now"
            amountRaw={isLoading ? null : pool}
            formatAmount={usd}
            caption={isLoading ? 'Loading from Arc Testnet' : `${live.length} open ${live.length === 1 ? 'bounty' : 'bounties'} on Arc Testnet`}
            visual={(tilt) => <BountyPoolVisual ids={live.map((i) => i.b.id)} tilt={tilt} />}
            stats={isLoading ? undefined : [
              { label: 'Open', value: String(live.length) },
              { label: 'Posted', value: String(bounties.length) },
              { label: 'Paid out', value: usd(paidOut), tone: 'success' },
            ]}
            refreshLabel="Refresh bounties"
            onRefresh={refresh}
          >
            <Button block onClick={() => setTab('post')}>Post a bounty</Button>
          </SummaryPanel>
        </>
      }
    >
      {wrongChain && (
        <div className="flex items-center gap-3 rounded-2xl px-4 py-3" style={{ background: 'rgba(240,128,140,0.12)', border: '1px solid rgba(240,128,140,0.3)' }}>
          <AlertTriangle className="size-4 shrink-0" style={{ color: c.danger }} />
          <p className="text-sm" style={{ color: c.danger }}>Switch to Arc Testnet to continue.</p>
          <Button variant="danger" size="sm" className="ml-auto" onClick={() => switchChain({ chainId: CHAIN_ID })}>Switch</Button>
        </div>
      )}

      <Tabs group="bounty-tabs" value={tab} onChange={setTab} tabs={[{ id: 'browse', label: 'Browse' }, { id: 'post', label: 'Post' }, { id: 'mine', label: 'My bounties', badge: needsReview }]} />

      <PendingCards app="bounty" />

      {tab === 'post' && <TabPanel><PostBountyForm onCreated={onPosted} /></TabPanel>}

      {tab === 'browse' && (
        <TabPanel>
        <section className="space-y-3">
          <div className="space-y-2.5 rounded-3xl p-3.5" style={glass.card}>
            <label className="flex items-center gap-2 rounded-2xl px-3 py-2.5" style={glass.inner}>
              <Search className="size-4 shrink-0" style={{ color: c.subtle }} />
              <input value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Search bounties" placeholder="Search bounties" className="w-full bg-transparent text-sm outline-none placeholder:text-slate-400" style={{ color: c.ink }} />
            </label>
            <div className="flex flex-wrap gap-1.5">
              <button aria-pressed={onlyOpen} onClick={() => setOnlyOpen((v) => !v)} className="btn min-h-11 rounded-xl px-3 text-xs font-semibold" style={chip(onlyOpen)}>Open only</button>
              <button aria-pressed={sort === 'reward'} onClick={() => setSort((s) => (s === 'new' ? 'reward' : 'new'))} className="btn min-h-11 rounded-xl px-3 text-xs font-semibold" style={chip(false)}>{sort === 'new' ? 'Newest' : 'Highest reward'}</button>
              {TAG_OPTIONS.map((t) => (
                <button key={t} aria-pressed={tag === t} onClick={() => setTag(tag === t ? '' : t)} className="btn min-h-11 rounded-xl px-3 text-xs font-semibold capitalize" style={chip(tag === t)}>{t}</button>
              ))}
            </div>
          </div>
          {isLoading ? (
            <div className="space-y-3">{[0, 1, 2].map((n) => <Skeleton key={n} className="h-32 rounded-3xl" />)}</div>
          ) : shown.length === 0 ? (
            bounties.length === 0
              ? <EmptyState kind="bounty" title="No bounties yet" body="Post the first one: set a USDC reward and let people compete for it." action={postCta} />
              : <EmptyState kind="bounty" title="Nothing matches" body="Try a different search, or turn off Open only." />
          ) : list(shown)}
        </section>
        </TabPanel>
      )}

      {tab === 'mine' && (
        <TabPanel>
        <section className="space-y-3">
          {!isConnected ? (
            <EmptyState kind="wallet" title="Connect a wallet" body="Connect to see the bounties you posted and who submitted work." action={<ConnectKitButton />} />
          ) : mine.length === 0 ? (
            <EmptyState kind="bounty" title="You have not posted a bounty yet" body="Bounties you post show up here, with their submissions." action={postCta} />
          ) : list([...mine].reverse())}
        </section>
        </TabPanel>
      )}
    </AppShell>
  )
}
