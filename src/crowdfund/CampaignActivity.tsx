import { CROWDFUND_ABI } from '@/crowdfundAbi'
import { short, usd } from '@/escrowTypes'
import { ActivityList } from '@/lib/ActivityList'
import type { ActivityItem } from '@/lib/ActivityList'
import { asBig, asStr, useContractEvents } from '@/lib/useContractEvents'
import { CROWDFUND_ADDRESS } from './crowdfundTypes'

const MAX_SHOWN = 12

/** Every onchain step of one campaign (pledges, payout, refunds), each with its transaction link. */
export function CampaignActivity({ campaignId }: { campaignId: bigint }) {
  const { data, isLoading, isError } = useContractEvents({ key: 'crowdfund', address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI })

  const rows: { block: bigint; index: number; item: ActivityItem }[] = []
  for (const e of data ?? []) {
    if (asBig(e.args.id) !== campaignId) continue
    const base = { key: `${e.transactionHash}-${e.logIndex}`, hash: e.transactionHash, timestamp: e.timestamp }
    const add = (label: string, detail?: string) => rows.push({ block: e.blockNumber, index: e.logIndex, item: { ...base, label, detail } })
    switch (e.eventName) {
      case 'CampaignCreated':
        add('Campaign started', `Goal ${usd(asBig(e.args.goal) ?? 0n)} USDC, by ${short(asStr(e.args.creator) ?? '')}`)
        break
      case 'Pledged':
        add('Pledge received', `${usd(asBig(e.args.amount) ?? 0n)} USDC from ${short(asStr(e.args.backer) ?? '')}`)
        break
      case 'FundsWithdrawn':
        add('Funds sent to the campaign wallet', `${usd(asBig(e.args.amount) ?? 0n)} USDC to ${short(asStr(e.args.beneficiary) ?? '')}`)
        break
      case 'Refunded':
        add('Pledge refunded', `${usd(asBig(e.args.amount) ?? 0n)} USDC back to ${short(asStr(e.args.backer) ?? '')}`)
        break
      case 'CampaignCancelled':
        add('Campaign cancelled by the creator')
        break
      case 'BeneficiaryUpdated':
        add('Campaign wallet changed', short(asStr(e.args.newBeneficiary) ?? ''))
        break
    }
  }
  rows.sort((a, b) => (a.block === b.block ? a.index - b.index : a.block < b.block ? -1 : 1))
  const latest = rows.slice(-MAX_SHOWN)

  return (
    <div className="space-y-2">
      <ActivityList items={latest.map((r) => r.item)} loading={isLoading} error={isError} />
      {rows.length > MAX_SHOWN && <p className="text-[11px]" style={{ color: '#8a97a6' }}>Showing the latest {MAX_SHOWN} of {rows.length} steps.</p>}
    </div>
  )
}
