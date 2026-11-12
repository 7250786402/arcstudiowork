import { useCallback, useMemo, useState } from 'react'
import { MotionConfig } from 'framer-motion'
import { useAccount, useReadContract, useReadContracts, useSwitchChain } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { AlertTriangle, ExternalLink } from 'lucide-react'
import { buildAddressExplorerUrl } from '@/onchain-facts'
import { ESCROW_ABI } from '@/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS, STATUS, ZERO, short, usd } from '@/escrowTypes'
import type { Deal } from '@/escrowTypes'
import { AppShell } from '@/ui/AppShell'
import { Button } from '@/ui/Button'
import { SummaryPanel } from '@/ui/SummaryPanel'
import { Tabs } from '@/ui/Tabs'
import { VaultVisual } from '@/ui/VaultVisual'
import { DealList } from './DealList'
import type { Filter } from './DealList'
import { Guide } from './Guide'
import { NewDealForm } from './NewDealForm'
import { c, display } from './theme'
import { useNow } from '@/bounty/useNow'
import { escrowLockedSeries } from '@/lib/series'
import { ActivityChart } from '@/ui/ActivityChart'
import { useDealEvents } from './useDealEvents'
import { TabPanel } from '@/ui/TabPanel'
import { PendingCards } from '@/ui/PendingCards'
import { useFreshKeys } from '@/ui/useFreshKeys'

type Tab = 'deals' | 'new'

const isActive = (s: number) => s <= STATUS.Delivered || s === STATUS.Disputed

/** Reads ?deal=<id> once so a shared link opens that deal directly. */
function readLinkedId(): bigint | null {
  const v = new URLSearchParams(window.location.search).get('deal')
  return v && /^\d{1,9}$/.test(v) ? BigInt(v) : null
}

export default function EscrowApp() {
  const nowSec = useNow()
  const events = useDealEvents()
  const lockedSeries = useMemo(() => escrowLockedSeries(events.data), [events.data])
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

  const refresh = useCallback(() => { void refetchIds(); void refetchDeals() }, [refetchIds, refetchDeals])
  const onCreated = useCallback(() => { refresh(); setTab('deals'); setFilter('active') }, [refresh])

  const deals: Deal[] = (results ?? []).flatMap((r) => (r.status === 'success' ? [r.result] : []))
  const active = deals.filter((d) => isActive(d.status))
  const fresh = useFreshKeys(deals.map((d) => d.id.toString()), !idsLoading)
  const shown = (filter === 'active' ? active : deals.filter((d) => !isActive(d.status))).filter((d) => d.id !== linkedId)
  const me = address?.toLowerCase()
  const locked = active.filter((d) => d.buyer.toLowerCase() === me).reduce((s, d) => s + d.amount, 0n)
  const incoming = active.filter((d) => d.seller.toLowerCase() === me).reduce((s, d) => s + d.amount, 0n)

  return (
    <MotionConfig reducedMotion="user">
      <AppShell
        side={
          <>
            <header className="flex items-center justify-between gap-3">
              <div className="min-w-0">
                <h1 className="text-xl font-bold text-balance" style={{ ...display, color: c.ink }}>Escrow</h1>
                <p className="text-sm text-pretty" style={{ color: c.muted }}>Lock USDC until both sides agree. If they disagree, an arbiter or an agreed timer settles it.</p>
              </div>
              <ConnectKitButton />
            </header>
            <SummaryPanel
              chart={<ActivityChart title="Locked in all deals" points={lockedSeries} nowSec={nowSec} />}
              eyebrow="Held in escrow for you"
              amountRaw={isConnected && !idsLoading ? locked + incoming : null}
              formatAmount={usd}
              caption={isConnected ? 'Across your active deals' : 'Connect your wallet to see your deals'}
              visual={(tilt) => <VaultVisual heldCount={active.length} tilt={tilt} />}
              stats={isConnected && !idsLoading ? [
                { label: 'You locked', value: usd(locked) },
                { label: 'Coming to you', value: usd(incoming), tone: 'success' },
                { label: 'Active deals', value: String(active.length) },
              ] : undefined}
              refreshLabel="Refresh deals"
              onRefresh={refresh}
            >
              <Button block onClick={() => setTab('new')}>New deal</Button>
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

        <Guide />
        <Tabs group="escrow-tabs" value={tab} onChange={setTab} tabs={[{ id: 'deals', label: 'My deals' }, { id: 'new', label: 'New deal' }]} />
        <PendingCards app="escrow" />

        {tab === 'new' && <TabPanel><NewDealForm onCreated={onCreated} /></TabPanel>}
        {tab === 'deals' && (
          <TabPanel>
          <DealList
            address={address}
            isConnected={isConnected}
            loading={idsLoading}
            fresh={fresh}
            filter={filter}
            onFilter={setFilter}
            activeCount={active.length}
            shown={shown}
            linkedId={linkedId}
            onChanged={refresh}
            onCreate={() => setTab('new')}
          />
          </TabPanel>
        )}

        <footer className="pb-4 text-center">
          <a href={buildAddressExplorerUrl(CHAIN_ID, ESCROW_ADDRESS)} target="_blank" rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs tabular-nums" style={{ color: c.subtle }}>
            Contract {short(ESCROW_ADDRESS)}<ExternalLink className="size-3" />
          </a>
        </footer>
      </AppShell>
    </MotionConfig>
  )
}
