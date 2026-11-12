import { useCallback, useState } from 'react'
import type { ReactNode } from 'react'
import { erc20Abi } from 'viem'
import { ChevronDown, Clock, Loader2, Trophy, Users } from 'lucide-react'
import { CHAIN_ID, USDC_ADDRESS, short, usd } from '@/escrowTypes'
import type { Addr } from '@/escrowTypes'
import { parseAmount } from '@/onchain-money'
import { BOUNTY_ABI } from '@/bountyAbi'
import { CONTRACT_ADDRESS, fmtDeadline } from '@/bountyTypes'
import type { Bounty, Submission } from '@/bountyTypes'
import { c, display, glass } from '@/escrow/theme'
import { useTxFlow } from '@/escrow/useTxFlow'
import { BountyActivity } from './BountyActivity'
import { useNow } from './useNow'

const TAG_COLOR: Record<string, string> = {
  design: '#7d5fd0', development: '#2d7fc4', content: '#1f9d6a', marketing: '#b7791f', research: '#c0392b', bug: '#d35400', other: '#5c6b7c',
}

function Spin({ children }: { children: ReactNode }) {
  return <span className="flex items-center justify-center gap-2"><Loader2 className="size-4 animate-spin" />{children}</span>
}

function Btn({ children, onClick, disabled, kind = 'primary' }: { children: ReactNode; onClick: () => void; disabled?: boolean; kind?: 'primary' | 'success' | 'danger' | 'ghost' }) {
  const style =
    kind === 'primary' ? { background: c.accent, color: '#fff' }
    : kind === 'success' ? { background: c.success, color: '#fff' }
    : kind === 'danger' ? { color: c.danger, background: 'rgba(192,57,43,0.08)' }
    : { color: c.ink, ...glass.inner }
  return (
    <button onClick={onClick} disabled={disabled}
      className="min-h-11 w-full rounded-2xl px-4 text-sm font-semibold transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40" style={style}>
      {children}
    </button>
  )
}

export function BountyCard({ bounty, subs, me, onChanged }: { bounty: Bounty; subs: readonly Submission[]; me?: Addr; onChanged: () => void }) {
  const [open, setOpen] = useState(false)
  const [note, setNote] = useState('')
  const [confirmFor, setConfirmFor] = useState<Addr | null>(null)
  const [tipOpen, setTipOpen] = useState(false)
  const [tipAmt, setTipAmt] = useState('1')
  const [tipRaw, setTipRaw] = useState<bigint | null>(null)
  const now = useNow()

  const act = useTxFlow(onChanged)
  const tip = useTxFlow(onChanged)
  const { run: runTip } = tip
  const onTipApproved = useCallback(() => {
    if (tipRaw === null) return
    void runTip((w) => w({ address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'tipWinner', args: [bounty.id, tipRaw], chainId: CHAIN_ID }))
  }, [runTip, tipRaw, bounty.id])
  const tipApprove = useTxFlow(onTipApproved)

  const meL = me?.toLowerCase()
  const isCreator = !!meL && meL === bounty.creator.toLowerCase()
  const isOpen = bounty.status === 0
  const isClaimed = bounty.status === 1
  const expired = bounty.deadline > 0n && BigInt(now) > bounty.deadline
  const mySub = subs.find((s) => s.submitter.toLowerCase() === meL)
  const tags = bounty.tags ? bounty.tags.split(',').map((t) => t.trim()).filter(Boolean) : []
  const error = act.error || tip.error || tipApprove.error

  const chip = isClaimed ? { t: 'Awarded', bg: 'rgba(26,128,71,0.12)', fg: c.success }
    : bounty.status === 2 ? { t: 'Cancelled', bg: 'rgba(92,107,124,0.12)', fg: c.muted }
    : expired ? { t: 'Expired', bg: 'rgba(183,121,31,0.12)', fg: c.warn }
    : { t: 'Open', bg: 'rgba(18,45,69,0.08)', fg: c.accent }

  const call = (fn: 'withdrawSubmission' | 'cancelBounty' | 'claimExpiredBounty') =>
    void act.run((w) => w({ address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: fn, args: [bounty.id], chainId: CHAIN_ID }))
  const submit = () =>
    void act.run((w) => w({ address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'submitWork', args: [bounty.id, note.trim()], chainId: CHAIN_ID }))
  const award = (who: Addr) => {
    setConfirmFor(null)
    void act.run((w) => w({ address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'approveClaimer', args: [bounty.id, who], chainId: CHAIN_ID }))
  }
  const sendTip = () => {
    let raw: bigint
    try { raw = parseAmount(CHAIN_ID, tipAmt).raw } catch { return }
    if (raw <= 0n) return
    setTipRaw(raw)
    void tipApprove.run((w) => w({ address: USDC_ADDRESS, abi: erc20Abi, functionName: 'approve', args: [CONTRACT_ADDRESS, raw], chainId: CHAIN_ID }))
  }

  return (
    <article className="lift overflow-hidden rounded-3xl" style={glass.card}>
      <button onClick={() => setOpen((v) => !v)} aria-expanded={open} className="w-full p-4 text-left">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold" style={{ ...display, color: c.ink }}>{bounty.title}</p>
            <div className="mt-1 flex flex-wrap gap-1">
              {tags.map((t) => (
                <span key={t} className="rounded-full px-2 py-0.5 text-[10px] font-semibold capitalize" style={{ color: TAG_COLOR[t] ?? c.muted, background: 'rgba(18,45,69,0.06)' }}>{t}</span>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className="rounded-full px-2.5 py-1 text-[11px] font-semibold" style={{ background: chip.bg, color: chip.fg }}>{chip.t}</span>
            <ChevronDown className="size-4 transition-transform" style={{ color: c.subtle, transform: open ? 'rotate(180deg)' : 'none' }} />
          </div>
        </div>
        <div className="mt-3 flex items-end justify-between">
          <div className="flex items-baseline gap-1">
            <span className="text-3xl font-bold tabular-nums" style={{ ...display, color: c.ink }}>{usd(bounty.reward)}</span>
            <span className="text-sm font-medium" style={{ color: c.subtle }}>USDC</span>
          </div>
          <div className="flex items-center gap-3 text-xs" style={{ color: c.muted }}>
            {bounty.deadline > 0n && isOpen && <span className="flex items-center gap-1"><Clock className="size-3" />{fmtDeadline(bounty.deadline)}</span>}
            <span className="flex items-center gap-1 tabular-nums"><Users className="size-3" />{subs.length}</span>
          </div>
        </div>
      </button>

      {open && (
        <div className="space-y-3 px-4 pb-4">
          <p className="whitespace-pre-wrap text-sm text-pretty" style={{ color: c.ink }}>{bounty.description}</p>
          {bounty.acceptanceCriteria && (
            <div className="rounded-2xl p-3.5" style={glass.inner}>
              <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>What counts as done</p>
              <p className="mt-1 text-sm text-pretty" style={{ color: c.ink }}>{bounty.acceptanceCriteria}</p>
            </div>
          )}
          <p className="text-xs" style={{ color: c.muted }}>
            Posted by {isCreator ? 'you' : short(bounty.creator)}{bounty.estimatedHours > 0n ? ` · about ${bounty.estimatedHours.toString()}h of work` : ''}
          </p>

          {subs.length > 0 && (
            <div className="space-y-2">
              <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Submissions ({subs.length})</p>
              {subs.map((s) => (
                <div key={s.submitter} className="rounded-2xl p-3" style={glass.inner}>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold tabular-nums" style={{ color: c.accent }}>{short(s.submitter)}{s.submitter.toLowerCase() === meL ? ' (you)' : ''}</span>
                    {isCreator && isOpen && (confirmFor === s.submitter ? (
                      <span className="flex gap-1.5">
                        <button onClick={() => award(s.submitter)} disabled={act.busy} className="min-h-9 rounded-xl px-3 text-xs font-semibold text-white disabled:opacity-40" style={{ background: c.success }}>Confirm</button>
                        <button onClick={() => setConfirmFor(null)} className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={{ color: c.muted }}>No</button>
                      </span>
                    ) : (
                      <button onClick={() => setConfirmFor(s.submitter)} className="flex min-h-9 items-center gap-1 rounded-xl px-3 text-xs font-semibold text-white" style={{ background: c.success }}>
                        <Trophy className="size-3" />Pick winner
                      </button>
                    ))}
                  </div>
                  <p className="mt-1 text-sm text-pretty" style={{ color: c.ink }}>{s.submissionNote}</p>
                </div>
              ))}
              {isCreator && isOpen && <p className="text-xs" style={{ color: c.subtle }}>Picking a winner pays {usd(bounty.reward)} USDC to them right away.</p>}
            </div>
          )}

          {isClaimed && (
            <div className="space-y-2">
              <p className="rounded-2xl px-3.5 py-3 text-sm font-medium" style={{ background: 'rgba(26,128,71,0.08)', color: c.success }}>
                Winner: {short(bounty.claimer)}{bounty.claimer.toLowerCase() === meL ? ' (you)' : ''}
              </p>
              {me && !tipOpen && <Btn kind="ghost" onClick={() => setTipOpen(true)}>Tip the winner</Btn>}
              {me && tipOpen && (
                <div className="space-y-2">
                  <label className="flex items-center gap-2 rounded-2xl p-3" style={glass.inner}>
                    <span className="text-sm" style={{ color: c.muted }}>$</span>
                    <input inputMode="decimal" value={tipAmt} onChange={(e) => { if (/^\d*\.?\d{0,6}$/.test(e.target.value)) setTipAmt(e.target.value) }}
                      className="w-full bg-transparent text-sm font-semibold outline-none" style={{ color: c.ink }} />
                    <span className="text-xs" style={{ color: c.subtle }}>USDC</span>
                  </label>
                  <Btn kind="success" onClick={sendTip} disabled={tipApprove.busy || tip.busy || !tipAmt}>
                    {tipApprove.pending || tip.pending ? <Spin>Confirm in wallet...</Spin> : tipApprove.confirming || tip.confirming ? <Spin>Confirming...</Spin> : 'Send tip (2 wallet steps)'}
                  </Btn>
                </div>
              )}
            </div>
          )}

          {me && !isCreator && isOpen && !expired && !mySub && (
            <div className="space-y-2">
              <label className="block rounded-2xl p-3.5" style={glass.inner}>
                <span className="mb-1.5 block text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Your submission</span>
                <textarea value={note} rows={3} maxLength={500} onChange={(e) => setNote(e.target.value)} placeholder="Describe your work or paste a link"
                  className="w-full resize-none bg-transparent text-sm outline-none placeholder:text-slate-400" style={{ color: c.ink }} />
              </label>
              <Btn onClick={submit} disabled={!note.trim() || act.busy}>
                {act.pending ? <Spin>Confirm in wallet...</Spin> : act.confirming ? <Spin>Submitting...</Spin> : 'Submit work'}
              </Btn>
            </div>
          )}
          {me && !isCreator && isOpen && mySub && (
            <Btn kind="danger" onClick={() => call('withdrawSubmission')} disabled={act.busy}>
              {act.busy ? <Spin>Working...</Spin> : 'Withdraw my submission'}
            </Btn>
          )}
          {!me && isOpen && !expired && <p className="text-xs" style={{ color: c.muted }}>Connect your wallet to submit work.</p>}

          {isCreator && isOpen && (subs.length === 0 || expired) && (
            <Btn kind="danger" onClick={() => call(subs.length === 0 ? 'cancelBounty' : 'claimExpiredBounty')} disabled={act.busy}>
              {act.busy ? <Spin>Working...</Spin> : subs.length === 0 ? 'Cancel and get my USDC back' : 'Deadline passed: take my USDC back'}
            </Btn>
          )}

          <BountyActivity bountyId={bounty.id} />

          {error && <p className="rounded-2xl px-4 py-3 text-sm" style={{ color: c.danger, background: 'rgba(192,57,43,0.08)' }}>{error}</p>}
        </div>
      )}
    </article>
  )
}
