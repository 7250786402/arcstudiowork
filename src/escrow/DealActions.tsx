import { useState } from 'react'
import type { ReactNode } from 'react'
import { useReadContract } from 'wagmi'
import { isAddress } from 'viem'
import { Loader2 } from 'lucide-react'
import { parseAmount } from '@/onchain-money'
import { ESCROW_ABI } from '@/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS, STATUS, ZERO, usd } from '@/escrowTypes'
import type { Addr, Deal } from '@/escrowTypes'
import { c, glass } from './theme'
import { useTxFlow } from './useTxFlow'
import { Button } from '@/ui/Button'
import { AddressTag } from '@/ui/AddressAvatar'

type IdFn =
  | 'release' | 'refund' | 'cancelUnaccepted' | 'reclaimExpired' | 'claimAfterReviewWindow'
  | 'raiseDispute' | 'refundStaleDispute' | 'markDelivered' | 'withdrawSeller'

function Btn({ children, onClick, disabled, tone = 'primary' }: { children: ReactNode; onClick: () => void; disabled: boolean; tone?: 'primary' | 'success' | 'ghost' | 'danger' }) {
  return <Button block variant={tone} onClick={onClick} disabled={disabled}>{children}</Button>
}

function Note({ children }: { children: ReactNode }) {
  return <p className="text-xs text-pretty" style={{ color: c.muted }}>{children}</p>
}

export function DealActions({ deal, me, now, onChanged }: { deal: Deal; me?: Addr; now: number; onChanged: () => void }) {
  const tx = useTxFlow(onChanged)
  const [payout, setPayout] = useState('')
  const [confirm, setConfirm] = useState<'release' | 'refund' | null>(null)
  const [sellerShare, setSellerShare] = useState('')

  const meL = me?.toLowerCase()
  const isBuyer = meL === deal.buyer.toLowerCase()
  const isSeller = meL === deal.seller.toLowerCase()
  const isArbiter = deal.arbiter !== ZERO && meL === deal.arbiter.toLowerCase()
  const hasArbiter = deal.arbiter !== ZERO
  const windowS = Number(deal.reviewWindow)
  const pastDeadline = now > Number(deal.deliverBy)
  const reviewEnds = Number(deal.deliveredAt) + windowS

  const { data: arbiterTimeout } = useReadContract({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'ARBITER_TIMEOUT', chainId: CHAIN_ID })
  const { data: owed } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'sellerOwed', args: [deal.id], chainId: CHAIN_ID,
    query: { enabled: deal.status === STATUS.Released },
  })
  const resolved = deal.status === STATUS.Resolved
  const { data: buyerOwed } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'claimableOf', args: [deal.id, deal.buyer], chainId: CHAIN_ID, query: { enabled: resolved },
  })
  const { data: sellerOwedResolved } = useReadContract({
    address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'claimableOf', args: [deal.id, deal.seller], chainId: CHAIN_ID, query: { enabled: resolved },
  })

  const idCall = (fn: IdFn) =>
    void tx.run((w) => w({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: fn, args: [deal.id], chainId: CHAIN_ID }))
  const payoutValue = (payout || (isSeller ? me : '') || '')
  const payoutOk = isAddress(payoutValue)
  const accept = () =>
    void tx.run((w) => w({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'acceptDeal', args: [deal.id, payoutValue as Addr], chainId: CHAIN_ID }))
  const updatePayout = () =>
    void tx.run((w) => w({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'updatePayout', args: [deal.id, payoutValue as Addr], chainId: CHAIN_ID }))
  const claimFor = (beneficiary: Addr) =>
    void tx.run((w) => w({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'claimResolved', args: [deal.id, beneficiary], chainId: CHAIN_ID }))

  let shareRaw: bigint | null = null
  try { shareRaw = sellerShare ? parseAmount(CHAIN_ID, sellerShare).raw : null } catch { shareRaw = null }
  const shareOk = shareRaw !== null && shareRaw <= deal.amount
  const resolve = () => {
    if (shareRaw === null) return
    void tx.run((w) => w({ address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'resolveDispute', args: [deal.id, shareRaw], chainId: CHAIN_ID }))
  }

  const busy = tx.busy
  const label = (idle: string) => (tx.pending ? 'Confirm in wallet...' : tx.confirming ? 'Confirming...' : idle)
  const items: ReactNode[] = []
  const s = deal.status

  if (s === STATUS.Funded) {
    if (isSeller) {
      items.push(
        <div key="accept" className="space-y-2">
          <Note>Read the terms above. By accepting you agree to them. Your payment goes to the address below.</Note>
          <input value={payout || me || ''} onChange={(e) => setPayout(e.target.value.trim())} className="w-full rounded-2xl px-3.5 py-3 text-sm outline-none" style={{ ...glass.inner, color: c.ink }} aria-label="Payout address" />
          <Btn tone="success" disabled={busy || !payoutOk} onClick={accept}>{label('Accept deal')}</Btn>
        </div>,
      )
    }
    if (isBuyer) {
      items.push(<Note key="w">Waiting for the seller to accept. Until then you can take your USDC back.</Note>)
      items.push(<Btn key="c" tone="danger" disabled={busy} onClick={() => idCall(pastDeadline ? 'reclaimExpired' : 'cancelUnaccepted')}>{label('Cancel and get USDC back')}</Btn>)
    }
  }

  if (s === STATUS.Accepted) {
    if (isSeller) {
      if (!pastDeadline) items.push(<Btn key="d" tone="success" disabled={busy} onClick={() => idCall('markDelivered')}>{label('I have delivered')}</Btn>)
      items.push(<Btn key="r" tone="ghost" disabled={busy} onClick={() => setConfirm('refund')}>{label('Return USDC to buyer')}</Btn>)
    }
    if (isBuyer) {
      items.push(<Note key="n">Release only when you are happy with the work.</Note>)
      items.push(<Btn key="rel" tone="success" disabled={busy} onClick={() => setConfirm('release')}>{label(`Release ${usd(deal.amount)} USDC to seller`)}</Btn>)
      if (pastDeadline) items.push(<Btn key="x" tone="danger" disabled={busy} onClick={() => idCall('reclaimExpired')}>{label('Deadline passed: get USDC back')}</Btn>)
    }
  }

  if (s === STATUS.Delivered) {
    const canDispute = hasArbiter && (isSeller || (isBuyer && (windowS === 0 || now <= reviewEnds)))
    if (isBuyer) {
      items.push(<Note key="n">The seller says the work is delivered.{windowS > 0 ? ` Respond before it auto-releases on ${new Date(reviewEnds * 1000).toLocaleString()}.` : ''}</Note>)
      items.push(<Btn key="rel" tone="success" disabled={busy} onClick={() => setConfirm('release')}>{label(`Release ${usd(deal.amount)} USDC to seller`)}</Btn>)
    }
    if (isSeller) {
      if (windowS > 0 && now > reviewEnds) items.push(<Btn key="cl" tone="success" disabled={busy} onClick={() => idCall('claimAfterReviewWindow')}>{label('Review time is over: collect payment')}</Btn>)
      else items.push(<Note key="n">{windowS > 0 ? `You can collect automatically after ${new Date(reviewEnds * 1000).toLocaleString()} if the buyer stays silent.` : 'Waiting for the buyer to release.'}</Note>)
      items.push(<Btn key="rf" tone="ghost" disabled={busy} onClick={() => setConfirm('refund')}>{label('Return USDC to buyer')}</Btn>)
    }
    if (canDispute) items.push(<Btn key="dis" tone="danger" disabled={busy} onClick={() => idCall('raiseDispute')}>{label('Raise a dispute with the arbiter')}</Btn>)
  }

  if (s === STATUS.Released) {
    if (owed !== undefined && owed > 0n) items.push(<Btn key="wd" tone="success" disabled={busy} onClick={() => idCall('withdrawSeller')}>{label(`Send ${usd(owed)} USDC to seller payout`)}</Btn>)
    else items.push(<Note key="done">Payment was sent to the seller.</Note>)
    if (isSeller) {
      items.push(
        <div key="pay" className="space-y-2">
          <Note>Need a different payout address? Update it before withdrawing.</Note>
          <input value={payout} placeholder={deal.sellerPayout} onChange={(e) => setPayout(e.target.value.trim())} className="w-full rounded-2xl px-3.5 py-3 text-sm outline-none" style={{ ...glass.inner, color: c.ink }} aria-label="New payout address" />
          <Btn tone="ghost" disabled={busy || !isAddress(payout)} onClick={updatePayout}>{label('Update payout address')}</Btn>
        </div>,
      )
    }
  }

  if (s === STATUS.Disputed) {
    if (isArbiter) {
      items.push(
        <div key="res" className="space-y-2">
          <Note>Decide how much of the {usd(deal.amount)} USDC goes to the seller. The rest returns to the buyer.</Note>
          <input inputMode="decimal" value={sellerShare} placeholder="Seller gets (USDC)" onChange={(e) => { if (/^\d*\.?\d{0,6}$/.test(e.target.value)) setSellerShare(e.target.value) }} className="w-full rounded-2xl px-3.5 py-3 text-sm tabular-nums outline-none" style={{ ...glass.inner, color: c.ink }} />
          <Btn disabled={busy || !shareOk} onClick={resolve}>{label('Submit decision')}</Btn>
        </div>,
      )
    } else {
      items.push(<Note key="n">The arbiter is reviewing this dispute.</Note>)
    }
    if (isBuyer && arbiterTimeout !== undefined && now > Number(deal.disputedAt) + Number(arbiterTimeout)) {
      items.push(<Btn key="st" tone="danger" disabled={busy} onClick={() => idCall('refundStaleDispute')}>{label('Arbiter did not respond: get USDC back')}</Btn>)
    }
  }

  if (resolved) {
    if (buyerOwed !== undefined && buyerOwed > 0n) items.push(<Btn key="b" tone="ghost" disabled={busy} onClick={() => claimFor(deal.buyer)}>{label(`Send ${usd(buyerOwed)} USDC to buyer`)}</Btn>)
    if (sellerOwedResolved !== undefined && sellerOwedResolved > 0n) items.push(<Btn key="se" tone="success" disabled={busy} onClick={() => claimFor(deal.seller)}>{label(`Send ${usd(sellerOwedResolved)} USDC to seller`)}</Btn>)
    if ((buyerOwed ?? 0n) === 0n && (sellerOwedResolved ?? 0n) === 0n) items.push(<Note key="d">The arbiter's decision has been paid out.</Note>)
  }

  if (s === STATUS.Refunded) items.push(<Note key="rf">The USDC was returned to the buyer.</Note>)
  if (confirm) {
    const toSeller = confirm === 'release'
    const recipient = toSeller ? (deal.sellerPayout !== ZERO ? deal.sellerPayout : deal.seller) : deal.buyer
    return (
      <div className="space-y-2.5">
        <div className="rounded-2xl p-3" style={glass.inner}>
          <p className="text-sm font-semibold" style={{ color: c.ink }}>{toSeller ? 'Release the payment?' : 'Return the USDC to the buyer?'}</p>
          <p className="mt-1 text-xs text-pretty" style={{ color: c.muted }}>
            {usd(deal.amount)} USDC will go to <AddressTag address={recipient} size={14} />. This cannot be undone.
          </p>
        </div>
        <Btn tone={toSeller ? 'success' : 'danger'} disabled={busy} onClick={() => { setConfirm(null); idCall(confirm) }}>{label(toSeller ? 'Yes, release it' : 'Yes, return it')}</Btn>
        <Btn tone="ghost" disabled={busy} onClick={() => setConfirm(null)}>Not yet</Btn>
      </div>
    )
  }
  if (items.length === 0) return null

  return (
    <div className="space-y-2.5">
      {items}
      {tx.busy && <p className="flex items-center gap-2 text-xs" style={{ color: c.muted }}><Loader2 className="size-3.5 animate-spin" />{tx.pending ? 'Waiting for your wallet' : 'Waiting for network confirmation'}</p>}
      {tx.error && <p className="rounded-xl px-3 py-2 text-xs" style={{ color: c.danger, background: 'rgba(240,128,140,0.08)' }}>{tx.error}</p>}
    </div>
  )
}
