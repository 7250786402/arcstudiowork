import { useCallback, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { useReadContract } from 'wagmi'
import { erc20Abi, isAddress } from 'viem'
import { ChevronDown, Clock, Loader2, Users } from 'lucide-react'
import { parseAmount } from '@/onchain-money'
import { CHAIN_ID, USDC_ADDRESS, ZERO, short, usd } from '@/escrowTypes'
import type { Addr } from '@/escrowTypes'
import { CROWDFUND_ABI } from '@/crowdfundAbi'
import { c, display, glass } from '@/escrow/theme'
import { useTxFlow } from '@/escrow/useTxFlow'
import { useNow } from '@/bounty/useNow'
import { CampaignActivity } from './CampaignActivity'
import { CROWDFUND_ADDRESS, STATUS, STATUS_LABEL, percent, timeLeft } from './crowdfundTypes'
import type { Campaign } from './crowdfundTypes'

const QUICK = ['5', '10', '25']

function Btn({ children, onClick, disabled, tone = 'primary' }: { children: ReactNode; onClick: () => void; disabled?: boolean; tone?: 'primary' | 'danger' | 'ghost' }) {
  const style = tone === 'primary' ? { background: c.accent, color: '#fff' } : tone === 'danger' ? { background: 'rgba(192,57,43,0.1)', color: c.danger } : { color: c.muted, ...glass.inner }
  return (
    <button onClick={onClick} disabled={disabled} className="flex min-h-11 w-full items-center justify-center gap-2 rounded-2xl px-4 text-sm font-semibold disabled:opacity-50" style={style}>
      {children}
    </button>
  )
}

const chipTone = (status: number) =>
  status === STATUS.Active ? { background: 'rgba(18,45,69,0.08)', color: c.accent }
    : status === STATUS.Succeeded || status === STATUS.Withdrawn ? { background: 'rgba(26,128,71,0.12)', color: c.success }
      : { background: 'rgba(138,151,166,0.18)', color: c.muted }

export function CampaignCard({ campaign, status, myPledge, me, onChanged }: {
  campaign: Campaign; status: number; myPledge: bigint; me?: Addr; onChanged: () => void
}) {
  const [open, setOpen] = useState(false)
  const [amount, setAmount] = useState('10')
  const [newPayout, setNewPayout] = useState('')
  const nowSec = useNow()
  const isCreator = !!me && me.toLowerCase() === campaign.creator.toLowerCase()
  const pct = percent(campaign.raised, campaign.goal)
  const live = status === STATUS.Active

  const pledgeRaw = useMemo(() => {
    try { const v = parseAmount(CHAIN_ID, amount).raw; return v > 0n ? v : null } catch { return null }
  }, [amount])

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: 'allowance', args: [me ?? ZERO, CROWDFUND_ADDRESS], chainId: CHAIN_ID,
    query: { enabled: !!me && live && open },
  })
  const needsApproval = pledgeRaw !== null && (allowance ?? 0n) < pledgeRaw

  const onApproved = useCallback(() => { void refetchAllowance() }, [refetchAllowance])
  const onPledged = useCallback(() => { onChanged(); void refetchAllowance() }, [onChanged, refetchAllowance])
  const approve = useTxFlow(onApproved)
  const pledge = useTxFlow(onPledged)
  const act = useTxFlow(onChanged)
  const error = approve.error || pledge.error || act.error

  const doApprove = () => {
    if (pledgeRaw === null) return
    void approve.run((w) => w({ address: USDC_ADDRESS, abi: erc20Abi, functionName: 'approve', args: [CROWDFUND_ADDRESS, pledgeRaw], chainId: CHAIN_ID }))
  }
  const doPledge = () => {
    if (pledgeRaw === null) return
    void pledge.run((w) => w({ address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'pledge', args: [campaign.id, pledgeRaw], chainId: CHAIN_ID }))
  }
  const idCall = (fn: 'withdrawFunds' | 'refund' | 'cancelCampaign') => () => {
    void act.run((w) => w({ address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: fn, args: [campaign.id], chainId: CHAIN_ID }))
  }
  const doUpdate = () => {
    if (!isAddress(newPayout)) return
    void act.run((w) => w({ address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'updateBeneficiary', args: [campaign.id, newPayout], chainId: CHAIN_ID }))
  }
  const spin = (busy: boolean) => busy && <Loader2 className="size-4 animate-spin" />

  return (
    <article className="lift overflow-hidden rounded-3xl" style={glass.card}>
      <button onClick={() => setOpen((v) => !v)} aria-expanded={open} className="block w-full p-4 text-left">
        <div className="flex items-start justify-between gap-3">
          <h3 className="text-[15px] font-semibold leading-snug text-balance" style={{ ...display, color: c.ink }}>{campaign.title}</h3>
          <span className="shrink-0 rounded-lg px-2 py-1 text-[11px] font-semibold" style={chipTone(status)}>{STATUS_LABEL[status] ?? 'Unknown'}</span>
        </div>
        <div className="mt-3 h-2 overflow-hidden rounded-full" style={{ background: 'rgba(18,45,69,0.08)' }} role="progressbar" aria-valuenow={Math.min(100, Math.round(pct))} aria-valuemin={0} aria-valuemax={100} aria-label="Funding progress">
          <div className="h-full rounded-full transition-[width] duration-500" style={{ width: `${Math.min(100, pct)}%`, background: pct >= 100 ? c.success : c.accent }} />
        </div>
        <div className="mt-2 flex items-baseline justify-between gap-2">
          <p className="text-sm tabular-nums" style={{ color: c.ink }}>
            <span className="font-bold">{usd(campaign.raised)}</span>
            <span style={{ color: c.muted }}> of {usd(campaign.goal)} USDC</span>
          </p>
          <p className="text-xs font-semibold tabular-nums" style={{ color: pct >= 100 ? c.success : c.muted }}>{Math.floor(pct)}% funded</p>
        </div>
        <div className="mt-2 flex items-center justify-between text-xs" style={{ color: c.muted }}>
          <span className="flex items-center gap-1"><Clock className="size-3.5" />{live ? timeLeft(campaign.deadline, nowSec) : 'Ended'}</span>
          <span className="flex items-center gap-1"><Users className="size-3.5" />by {short(campaign.creator)}<ChevronDown className={`size-4 transition-transform ${open ? 'rotate-180' : ''}`} /></span>
        </div>
      </button>

      {open && (
        <div className="space-y-3 border-t px-4 pb-4 pt-3" style={{ borderColor: 'rgba(18,45,69,0.08)' }}>
          {campaign.description && <p className="whitespace-pre-line text-sm text-pretty" style={{ color: c.ink }}>{campaign.description}</p>}
          <p className="text-xs" style={{ color: c.muted }}>Paid out to <span className="font-mono">{short(campaign.beneficiary)}</span> if the goal is reached.</p>
          {myPledge > 0n && <p className="rounded-xl px-3 py-2 text-xs font-semibold" style={{ background: 'rgba(26,128,71,0.1)', color: c.success }}>You pledged {usd(myPledge)} USDC</p>}

          {live && !me && <p className="text-xs" style={{ color: c.muted }}>Connect a wallet to back this campaign.</p>}

          {live && me && (
            <div className="space-y-2">
              <p className="text-xs font-semibold" style={{ color: c.ink }}>Back this campaign</p>
              <div className="flex gap-1.5">
                {QUICK.map((q) => (
                  <button key={q} onClick={() => setAmount(q)} className="min-h-10 flex-1 rounded-xl text-sm font-semibold tabular-nums" style={amount === q ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>{q}</button>
                ))}
                <input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" aria-label="Pledge amount in USDC" className="min-h-10 w-24 rounded-xl px-3 text-right text-sm tabular-nums outline-none" style={{ ...glass.inner, color: c.ink }} />
              </div>
              {needsApproval ? (
                <Btn onClick={doApprove} disabled={pledgeRaw === null || approve.busy}>{spin(approve.busy)}{approve.pending ? 'Confirm in wallet' : approve.confirming ? 'Approving' : `Step 1 of 2: allow ${amount || '0'} USDC`}</Btn>
              ) : (
                <Btn onClick={doPledge} disabled={pledgeRaw === null || pledge.busy}>{spin(pledge.busy)}{pledge.pending ? 'Confirm in wallet' : pledge.confirming ? 'Pledging' : `Pledge ${amount || '0'} USDC`}</Btn>
              )}
              <p className="text-[11px] text-pretty" style={{ color: c.muted }}>If the goal is not reached by the deadline, you can take your USDC back.</p>
            </div>
          )}

          {status === STATUS.Succeeded && (
            <div className="space-y-2">
              <p className="text-xs text-pretty" style={{ color: c.muted }}>The goal was reached. Anyone can send the money to the campaign wallet.</p>
              <Btn onClick={idCall('withdrawFunds')} disabled={act.busy}>{spin(act.busy)}Send {usd(campaign.raised)} USDC to the campaign wallet</Btn>
            </div>
          )}

          {(status === STATUS.Failed || status === STATUS.Cancelled) && myPledge > 0n && (
            <Btn onClick={idCall('refund')} disabled={act.busy}>{spin(act.busy)}Take back my {usd(myPledge)} USDC</Btn>
          )}
          {(status === STATUS.Failed || status === STATUS.Cancelled) && myPledge === 0n && (
            <p className="text-xs text-pretty" style={{ color: c.muted }}>{status === STATUS.Failed ? 'The goal was not reached, so backers can take their USDC back.' : 'This campaign was cancelled, so backers can take their USDC back.'}</p>
          )}

          {isCreator && status !== STATUS.Withdrawn && status !== STATUS.Cancelled && (
            <div className="space-y-2 border-t pt-3" style={{ borderColor: 'rgba(18,45,69,0.08)' }}>
              <p className="text-xs font-semibold" style={{ color: c.ink }}>Your controls</p>
              <div className="flex gap-1.5">
                <input value={newPayout} onChange={(e) => setNewPayout(e.target.value)} placeholder="New payout wallet 0x..." aria-label="New payout wallet" className="min-h-10 min-w-0 flex-1 rounded-xl px-3 font-mono text-xs outline-none" style={{ ...glass.inner, color: c.ink }} />
                <button onClick={doUpdate} disabled={!isAddress(newPayout) || act.busy} className="min-h-10 rounded-xl px-3 text-xs font-semibold disabled:opacity-50" style={{ color: c.muted, ...glass.inner }}>Update</button>
              </div>
              {live && <Btn tone="danger" onClick={idCall('cancelCampaign')} disabled={act.busy}>{spin(act.busy)}Cancel campaign and refund backers</Btn>}
            </div>
          )}

          <CampaignActivity campaignId={campaign.id} />

          {error && <p role="alert" className="text-xs" style={{ color: c.danger }}>{error}</p>}
        </div>
      )}
    </article>
  )
}
