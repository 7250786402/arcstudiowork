import { useCallback, useMemo, useState } from 'react'
import { MotionConfig } from 'framer-motion'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle } from 'lucide-react'
import { CHAIN_ID, ZERO, usd } from '@/escrowTypes'
import { CROWDFUND_ABI } from '@/crowdfundAbi'
import { c, display, glass } from '@/escrow/theme'
import { AppShell } from '@/ui/AppShell'
import { Button } from '@/ui/Button'
import { EmptyState } from '@/ui/EmptyState'
import { GoalVisual } from '@/ui/GoalRing'
import { Reveal } from '@/ui/Reveal'
import { Skeleton } from '@/ui/Skeleton'
import { SummaryPanel } from '@/ui/SummaryPanel'
import { Tabs } from '@/ui/Tabs'
import { CampaignCard } from './CampaignCard'
import { StartCampaignForm } from './StartCampaignForm'
import { CROWDFUND_ADDRESS, STATUS } from './crowdfundTypes'
import type { Campaign } from './crowdfundTypes'
import { useNow } from '@/bounty/useNow'
import { useContractEvents } from '@/lib/useContractEvents'
import { crowdfundHeldSeries } from '@/lib/series'
import { ActivityChart } from '@/ui/ActivityChart'
import { TabPanel } from '@/ui/TabPanel'
import { PendingCards } from '@/ui/PendingCards'
import { useFreshKeys } from '@/ui/useFreshKeys'

type Tab = 'discover' | 'start' | 'mine'

const chip = (on: boolean) => (on ? { background: c.accent, color: c.onAccent } : { color: c.muted, ...glass.inner })

export default function CrowdfundApp() {
  const nowSec = useNow()
  const events = useContractEvents({ key: 'crowdfund', address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI })
  const heldSeries = useMemo(() => crowdfundHeldSeries(events.data), [events.data])
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

  const fresh = useFreshKeys(ids.map((id) => id.toString()), !isLoading)
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
  const goalLive = live.reduce((sum, i) => sum + i.campaign.goal, 0n)
  const funded = items.filter((i) => i.status === STATUS.Succeeded || i.status === STATUS.Withdrawn).length
  const mine = items.filter((i) => i.campaign.creator.toLowerCase() === meL || i.pledge > 0n)
  const needsAction = mine.filter((i) =>
    ((i.status === STATUS.Failed || i.status === STATUS.Cancelled) && i.pledge > 0n)
    || (i.status === STATUS.Succeeded && i.campaign.creator.toLowerCase() === meL)).length
  const shown = items.filter((i) => (liveOnly ? i.status === STATUS.Active : true))

  const startCta = <Button onClick={() => setTab('start')}>Start a campaign</Button>
  const list = (rows: typeof items) => rows.map((i, n) => (
    <Reveal key={i.campaign.id.toString()} index={n} fresh={fresh.has(i.campaign.id.toString())}>
      <CampaignCard campaign={i.campaign} status={i.status} myPledge={i.pledge} me={address} onChanged={refresh} />
    </Reveal>
  ))

  return (
    <MotionConfig reducedMotion="user">
      <AppShell
        side={
          <>
            <header className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <h1 className="text-xl font-bold text-balance" style={{ ...display, color: c.ink }}>Crowdfund</h1>
                <p className="text-sm text-pretty" style={{ color: c.muted }}>Set a goal and a deadline. Reach it and the funds go out. Miss it and every backer gets a refund.</p>
              </div>
              <ConnectKitButton />
            </header>
            <SummaryPanel
              chart={<ActivityChart title="Held in all campaigns" points={heldSeries} nowSec={nowSec} />}
              eyebrow="Raised in live campaigns"
              amountRaw={isLoading ? null : raisedLive}
              formatAmount={usd}
              caption={isLoading ? 'Loading from Arc Testnet' : `${live.length} live ${live.length === 1 ? 'campaign' : 'campaigns'} on Arc Testnet`}
              visual={(tilt) => <GoalVisual raised={raisedLive} goal={goalLive} tilt={tilt} />}
              stats={isLoading ? undefined : [
                { label: 'Live', value: String(live.length) },
                { label: 'Started', value: String(items.length) },
                { label: 'Funded', value: String(funded), tone: 'success' },
              ]}
              refreshLabel="Refresh campaigns"
              onRefresh={refresh}
            >
              <Button block onClick={() => setTab('start')}>Start a campaign</Button>
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

        <Tabs group="crowdfund-tabs" value={tab} onChange={setTab} tabs={[{ id: 'discover', label: 'Discover' }, { id: 'start', label: 'Start' }, { id: 'mine', label: 'Mine', badge: needsAction }]} />

        <PendingCards app="crowdfund" />

        {tab === 'start' && <TabPanel><StartCampaignForm onCreated={onCreated} /></TabPanel>}

        {tab === 'discover' && (
          <TabPanel>
          <section className="space-y-3">
            <div className="flex gap-1.5">
              <button onClick={() => setLiveOnly(true)} className="btn min-h-11 rounded-xl px-3 text-xs font-semibold" style={chip(liveOnly)}>Live</button>
              <button onClick={() => setLiveOnly(false)} className="btn min-h-11 rounded-xl px-3 text-xs font-semibold" style={chip(!liveOnly)}>All</button>
            </div>
            {isLoading ? (
              <div className="space-y-3">{[0, 1].map((n) => <Skeleton key={n} className="h-36 rounded-3xl" />)}</div>
            ) : shown.length === 0 ? (
              items.length === 0
                ? <EmptyState kind="crowdfund" title="No campaigns yet" body="Start the first one: set a goal and a deadline, and backers pledge USDC." action={startCta} />
                : <EmptyState kind="crowdfund" title="No live campaigns" body="Switch to All to see finished ones, or start your own." action={startCta} />
            ) : list(shown)}
          </section>
          </TabPanel>
        )}

        {tab === 'mine' && (
          <TabPanel>
          <section className="space-y-3">
            {!isConnected ? (
              <EmptyState kind="wallet" title="Connect a wallet" body="Connect to see the campaigns you started or backed." action={<ConnectKitButton />} />
            ) : mine.length === 0 ? (
              <EmptyState kind="crowdfund" title="Nothing here yet" body="Campaigns you start or back show up here." action={startCta} />
            ) : list(mine)}
          </section>
          </TabPanel>
        )}
      </AppShell>
    </MotionConfig>
  )
}
