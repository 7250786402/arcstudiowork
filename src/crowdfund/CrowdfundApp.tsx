import { useCallback, useMemo, useState } from 'react'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle, HandCoins } from 'lucide-react'
import { CHAIN_ID, ZERO, usd } from '@/escrowTypes'
import { CROWDFUND_ABI } from '@/crowdfundAbi'
import { SPECTRAL, c, display, glass } from '@/escrow/theme'
import { CampaignCard } from './CampaignCard'
import { StartCampaignForm } from './StartCampaignForm'
import { CROWDFUND_ADDRESS, STATUS } from './crowdfundTypes'
import type { Campaign } from './crowdfundTypes'
import { HeroCard } from '@/ui/HeroCard'

type Tab = 'discover' | 'start' | 'mine'

export default function CrowdfundApp() {
  const { address, chainId, isConnected } = useAccount()
  const { switchChain } = useSwitchChain()
  const [tab, setTab] = useState<Tab>('discover')
  const [liveOnly, setLiveOnly] = useState(true)
  const wrongChain = isConnected && chainId !== CHAIN_ID

  const { data: count, refetch: refetchCount, isLoading } = useReadContract({
    address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'campaignCount', chainId: CHAIN_ID,
    query: { refetchInterval: 15000 },
  })
  const ids = useMemo(() => Array.from({ length: Number(count ?? 0n) }, (_, i) => BigInt(i)), [count])
  const contracts = useMemo(() => ids.flatMap((id) => [
    { address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'getCampaign', args: [id], chainId: CHAIN_ID } as const,
    { address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'statusOf', args: [id], chainId: CHAIN_ID } as const,
    { address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'pledgeOf', args: [id, address ?? ZERO], chainId: CHAIN_ID } as const,
  ]), [ids, address])
  const { data: res, refetch: refetchAll } = useReadContracts({ contracts, query: { enabled: ids.length > 0, refetchInterval: 15000 } })

  const refresh = useCallback(() => { void refetchCount(); void refetchAll() }, [refetchCount, refetchAll])
  const onCreated = useCallback(() => { refresh(); setTab('discover'); setLiveOnly(true) }, [refresh])

  const items = ids.flatMap((_, i) => {
    const a = res?.[i * 3]
    const s = res?.[i * 3 + 1]
    const p = res?.[i * 3 + 2]
    if (!a || a.status !== 'success' || !s || s.status !== 'success') return []
    return [{
      campaign: a.result as Campaign,
      status: Number(s.result),
      pledge: p && p.status === 'success' ? (p.result as bigint) : 0n,
    }]
  }).reverse()

  const meL = address?.toLowerCase()
  const live = items.filter((i) => i.status === STATUS.Active)
  const raisedLive = live.reduce((sum, i) => sum + i.campaign.raised, 0n)
  const mine = items.filter((i) => i.campaign.creator.toLowerCase() === meL || i.pledge > 0n)
  const needsAction = mine.filter((i) =>
    ((i.status === STATUS.Failed || i.status === STATUS.Cancelled) && i.pledge > 0n)
    || (i.status === STATUS.Succeeded && i.campaign.creator.toLowerCase() === meL)).length
  const shown = items.filter((i) => (liveOnly ? i.status === STATUS.Active : true))

  const empty = (title: string, body: string, cta?: boolean) => (
    <div className="rounded-3xl p-8 text-center" style={glass.card}>
      <HandCoins className="mx-auto mb-2 size-7" style={{ color: c.subtle }} />
      <p className="text-sm font-semibold" style={{ color: c.ink }}>{title}</p>
      <p className="mx-auto mt-1 max-w-xs text-xs text-pretty" style={{ color: c.muted }}>{body}</p>
      {cta && <button onClick={() => setTab('start')} className="mt-4 min-h-11 rounded-2xl px-5 text-sm font-semibold text-white" style={{ background: c.accent }}>Start a campaign</button>}
    </div>
  )

  const card = (i: (typeof items)[number]) => (
    <CampaignCard key={i.campaign.id.toString()} campaign={i.campaign} status={i.status} myPledge={i.pledge} me={address} onChanged={refresh} />
  )

  return (
    <div className="min-h-dvh" style={{ fontFamily: "'DM Sans', sans-serif" }}>
      <div className="h-1 w-full" style={{ background: SPECTRAL }} />
      <main className="mx-auto max-w-md space-y-4 px-4 py-6">
        <header className="flex items-center justify-between">
          <div>
            <h1 className="text-lg font-bold text-balance" style={{ ...display, color: c.ink }}>Crowdfund</h1>
            <p className="text-xs" style={{ color: c.muted }}>Reach the goal or everyone gets their USDC back</p>
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
          label="Raised in live campaigns"
          amount={isLoading ? '--' : usd(raisedLive)}
          caption={isLoading ? 'Loading from Arc Testnet' : `${live.length} live ${live.length === 1 ? 'campaign' : 'campaigns'} on Arc Testnet`}
          refreshLabel="Refresh campaigns"
          onRefresh={refresh}
        />

        <nav className="flex gap-1 rounded-2xl p-1" style={glass.card} aria-label="Sections">
          {([['discover', 'Discover'], ['start', 'Start'], ['mine', 'Mine']] as const).map(([id, label]) => (
            <button key={id} onClick={() => setTab(id)} aria-current={tab === id} className="relative min-h-10 flex-1 rounded-xl text-sm font-semibold transition-colors"
              style={tab === id ? { background: c.accent, color: '#fff' } : { color: c.muted }}>
              {label}
              {id === 'mine' && needsAction > 0 && <span className="absolute -right-0.5 -top-1 flex size-4 items-center justify-center rounded-full text-[10px] font-bold text-white" style={{ background: c.danger }}>{needsAction}</span>}
            </button>
          ))}
        </nav>

        {tab === 'start' && <StartCampaignForm onCreated={onCreated} />}

        {tab === 'discover' && (
          <section className="space-y-3">
            <div className="flex gap-1.5">
              <button onClick={() => setLiveOnly(true)} className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={liveOnly ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>Live</button>
              <button onClick={() => setLiveOnly(false)} className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={!liveOnly ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>All</button>
            </div>
            {isLoading ? <div className="h-28 animate-pulse rounded-3xl" style={glass.card} />
              : shown.length === 0 ? (items.length === 0
                ? empty('No campaigns yet', 'Start the first one: set a goal and a deadline, and backers pledge USDC.', true)
                : empty('No live campaigns', 'Switch to All to see finished ones, or start your own.', true))
              : shown.map(card)}
          </section>
        )}

        {tab === 'mine' && (
          <section className="space-y-3">
            {!isConnected ? (
              <div className="rounded-3xl p-8 text-center" style={glass.card}>
                <p className="text-sm font-semibold" style={{ color: c.ink }}>Connect a wallet</p>
                <div className="mt-4 flex justify-center"><ConnectKitButton /></div>
              </div>
            ) : mine.length === 0 ? empty('Nothing here yet', 'Campaigns you start or back show up here.', true)
              : mine.map(card)}
          </section>
        )}
      </main>
    </div>
  )
}
