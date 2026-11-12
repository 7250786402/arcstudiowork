import { BOUNTY_EVENTS_ABI } from '@/bountyEvents'
import { CONTRACT_ADDRESS } from '@/bountyTypes'
import { short, usd } from '@/escrowTypes'
import { ActivityList } from '@/lib/ActivityList'
import type { ActivityItem } from '@/lib/ActivityList'
import { asBig, asStr, useContractEvents } from '@/lib/useContractEvents'

/** Every onchain step of one bounty (posting, submissions, payout, tips), each with its transaction link. */
export function BountyActivity({ bountyId }: { bountyId: bigint }) {
  const { data, isLoading, isError } = useContractEvents({ key: 'bounty', address: CONTRACT_ADDRESS, abi: BOUNTY_EVENTS_ABI })

  const rows: { block: bigint; index: number; item: ActivityItem }[] = []
  for (const e of data ?? []) {
    const id = asBig(e.args.id) ?? asBig(e.args.bountyId)
    if (id !== bountyId) continue
    const base = { key: `${e.transactionHash}-${e.logIndex}`, hash: e.transactionHash, timestamp: e.timestamp }
    const add = (label: string, detail?: string) => rows.push({ block: e.blockNumber, index: e.logIndex, item: { ...base, label, detail } })
    switch (e.eventName) {
      case 'BountyCreated':
        add('Bounty posted', `${usd(asBig(e.args.reward) ?? 0n)} USDC locked by ${short(asStr(e.args.creator) ?? '')}`)
        break
      case 'WorkSubmitted':
        add('Work submitted', `By ${short(asStr(e.args.submitter) ?? '')}`)
        break
      case 'SubmissionWithdrawn':
        add('Submission withdrawn', `By ${short(asStr(e.args.submitter) ?? '')}`)
        break
      case 'BountyClaimed':
        add('Reward paid out', `${usd(asBig(e.args.reward) ?? 0n)} USDC sent to ${short(asStr(e.args.claimer) ?? '')}`)
        break
      case 'WinnerTipped':
        add('Tip sent to the winner', `${usd(asBig(e.args.amount) ?? 0n)} USDC from ${short(asStr(e.args.tipper) ?? '')}`)
        break
      case 'BountyCancelled':
        add('Bounty closed, USDC returned to the poster')
        break
    }
  }
  rows.sort((a, b) => (a.block === b.block ? a.index - b.index : a.block < b.block ? -1 : 1))

  return <ActivityList items={rows.map((r) => r.item)} loading={isLoading} error={isError} />
}
