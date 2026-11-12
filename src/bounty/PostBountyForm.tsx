import { useCallback, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { erc20Abi } from 'viem'
import { ConnectKitButton } from 'connectkit'
import { Loader2 } from 'lucide-react'
import { parseAmount } from '@/onchain-money'
import { CHAIN_ID, USDC_ADDRESS, ZERO, usd } from '@/escrowTypes'
import { BOUNTY_ABI } from '@/bountyAbi'
import { CONTRACT_ADDRESS, TAG_OPTIONS } from '@/bountyTypes'
import { c, display, glass } from '@/escrow/theme'
import { useTxFlow } from '@/escrow/useTxFlow'

const DEADLINES = [
  { label: '3 days', days: 3 },
  { label: '1 week', days: 7 },
  { label: '2 weeks', days: 14 },
  { label: '1 month', days: 30 },
  { label: 'No deadline', days: 0 },
]

const TEMPLATES = [
  { label: 'Bug fix', title: 'Fix a bug in my smart contract', desc: 'Find and fix the reported bug and explain what caused it.', criteria: 'Fix works, includes a test, short write-up of the cause', tags: ['development', 'bug'], hours: '4' },
  { label: 'Design', title: 'Design a logo for my project', desc: 'Create a clean logo with a short rationale.', criteria: 'SVG and PNG files delivered, one round of changes', tags: ['design'], hours: '6' },
  { label: 'Article', title: 'Write an article about my product', desc: 'A clear, original article of about 800 words.', criteria: '800+ words, original, link to the published piece', tags: ['content'], hours: '3' },
]

function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block rounded-2xl p-3.5" style={glass.inner}>
      <span className="mb-1.5 block text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>{label}</span>
      {children}
      {hint && <span className="mt-1.5 block text-xs text-pretty" style={{ color: c.subtle }}>{hint}</span>}
    </label>
  )
}

function Spin({ children }: { children: ReactNode }) {
  return <span className="flex items-center justify-center gap-2"><Loader2 className="size-4 animate-spin" />{children}</span>
}

export function PostBountyForm({ onCreated }: { onCreated: () => void }) {
  const { address, isConnected } = useAccount()
  const [title, setTitle] = useState('')
  const [desc, setDesc] = useState('')
  const [criteria, setCriteria] = useState('')
  const [reward, setReward] = useState('')
  const [days, setDays] = useState(7)
  const [tags, setTags] = useState<string[]>([])
  const [hours, setHours] = useState('')

  const rewardRaw = useMemo(() => {
    try { return reward ? parseAmount(CHAIN_ID, reward).raw : null } catch { return null }
  }, [reward])

  const { data: balance } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [address ?? ZERO],
    chainId: CHAIN_ID, query: { enabled: !!address, refetchInterval: 10000 },
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: 'allowance', args: [address ?? ZERO, CONTRACT_ADDRESS],
    chainId: CHAIN_ID, query: { enabled: !!address },
  })

  const onApproved = useCallback(() => { void refetchAllowance() }, [refetchAllowance])
  const approve = useTxFlow(onApproved)
  const create = useTxFlow(onCreated)

  const enough = rewardRaw !== null && balance !== undefined && balance >= rewardRaw
  const needsApproval = rewardRaw !== null && (allowance ?? 0n) < rewardRaw
  const formOk = rewardRaw !== null && rewardRaw > 0n && title.trim() !== '' && desc.trim() !== ''

  const doApprove = () => {
    if (rewardRaw === null) return
    void approve.run((w) => w({ address: USDC_ADDRESS, abi: erc20Abi, functionName: 'approve', args: [CONTRACT_ADDRESS, rewardRaw], chainId: CHAIN_ID }))
  }
  const doCreate = () => {
    if (rewardRaw === null) return
    const deadline = days === 0 ? 0n : BigInt(Math.floor(Date.now() / 1000) + days * 86400)
    void create.run((w) => w({
      address: CONTRACT_ADDRESS, abi: BOUNTY_ABI, functionName: 'createBounty', chainId: CHAIN_ID,
      args: [title.trim(), desc.trim(), rewardRaw, tags.join(','), deadline, criteria.trim(), 0, BigInt(parseInt(hours || '0', 10) || 0)],
    }))
  }

  const toggleTag = (t: string) => setTags((p) => (p.includes(t) ? p.filter((x) => x !== t) : [...p, t]))
  const inputCls = 'w-full bg-transparent text-sm outline-none placeholder:text-slate-400'
  const err = approve.error || create.error

  return (
    <section className="space-y-3">
      <div className="rounded-3xl p-5" style={glass.card}>
        <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Reward</p>
        <div className="mt-1 flex items-baseline gap-1.5">
          <input inputMode="decimal" value={reward} placeholder="0.00"
            onChange={(e) => { const v = e.target.value; if (/^\d*\.?\d{0,6}$/.test(v)) setReward(v) }}
            className="w-full bg-transparent text-4xl font-bold tabular-nums outline-none placeholder:text-slate-300"
            style={{ ...display, color: c.ink }} />
          <span className="text-lg font-medium" style={{ color: c.subtle }}>USDC</span>
        </div>
        <div className="mt-3 flex items-center justify-between text-xs" style={{ color: c.muted }}>
          <div className="flex gap-1.5">
            {[5, 10, 25, 50].map((v) => (
              <button key={v} type="button" onClick={() => setReward(String(v))} className="min-h-9 rounded-xl px-3 font-semibold" style={glass.inner}>${v}</button>
            ))}
          </div>
          <span className="tabular-nums">{balance !== undefined ? `Balance ${usd(balance)}` : ''}</span>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-1.5">
        <span className="text-xs" style={{ color: c.muted }}>Start from:</span>
        {TEMPLATES.map((t) => (
          <button key={t.label} type="button" className="min-h-9 rounded-xl px-3 text-xs font-semibold" style={{ color: c.ink, ...glass.inner }}
            onClick={() => { setTitle(t.title); setDesc(t.desc); setCriteria(t.criteria); setTags(t.tags); setHours(t.hours) }}>
            {t.label}
          </button>
        ))}
      </div>

      <Field label="Title">
        <input value={title} maxLength={80} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Design a logo for my project" className={inputCls} style={{ color: c.ink }} />
      </Field>
      <Field label="What do you need?">
        <textarea value={desc} rows={3} maxLength={600} onChange={(e) => setDesc(e.target.value)} placeholder="Describe the work" className={`${inputCls} resize-none`} style={{ color: c.ink }} />
      </Field>
      <Field label="What counts as done? (optional)" hint="Clear criteria make it easy to pick a winner.">
        <textarea value={criteria} rows={2} maxLength={300} onChange={(e) => setCriteria(e.target.value)} placeholder="e.g. SVG delivered, one round of changes" className={`${inputCls} resize-none`} style={{ color: c.ink }} />
      </Field>

      <Field label="Skills">
        <div className="flex flex-wrap gap-1.5">
          {TAG_OPTIONS.map((t) => (
            <button key={t} type="button" onClick={() => toggleTag(t)} className="min-h-9 rounded-xl px-3 text-xs font-semibold capitalize"
              style={tags.includes(t) ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>{t}</button>
          ))}
        </div>
      </Field>

      <Field label="Deadline" hint={days === 0 ? 'Without a deadline, your USDC stays locked once someone submits, until you pick a winner.' : 'After the deadline you can take your USDC back if you have not picked a winner.'}>
        <div className="flex flex-wrap gap-1.5">
          {DEADLINES.map((d) => (
            <button key={d.label} type="button" onClick={() => setDays(d.days)} className="min-h-9 rounded-xl px-3 text-xs font-semibold"
              style={days === d.days ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>{d.label}</button>
          ))}
        </div>
      </Field>

      <Field label="Estimated hours (optional)">
        <input inputMode="numeric" value={hours} onChange={(e) => setHours(e.target.value.replace(/\D/g, '').slice(0, 3))} placeholder="0" className={inputCls} style={{ color: c.ink }} />
      </Field>

      {err && <p className="rounded-2xl px-4 py-3 text-sm" style={{ color: c.danger, background: 'rgba(192,57,43,0.08)' }}>{err}</p>}
      {rewardRaw !== null && balance !== undefined && !enough && (
        <p className="text-xs font-medium" style={{ color: c.danger }}>Your balance is lower than the reward. Use Get test USDC in the sidebar.</p>
      )}

      {!isConnected ? (
        <div className="flex justify-center"><ConnectKitButton /></div>
      ) : needsApproval ? (
        <button disabled={!formOk || !enough || approve.busy} onClick={doApprove}
          className="min-h-12 w-full rounded-2xl text-sm font-semibold text-white transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40" style={{ background: c.accent }}>
          {approve.pending ? <Spin>Confirm in wallet...</Spin> : approve.confirming ? <Spin>Allowing USDC...</Spin> : 'Step 1 of 2: Allow USDC'}
        </button>
      ) : (
        <button disabled={!formOk || !enough || create.busy} onClick={doCreate}
          className="min-h-12 w-full rounded-2xl text-sm font-semibold text-white transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40" style={{ background: c.success }}>
          {create.pending ? <Spin>Confirm in wallet...</Spin> : create.confirming ? <Spin>Posting bounty...</Spin> : `Step 2 of 2: Lock ${reward || '0'} USDC as reward`}
        </button>
      )}
    </section>
  )
}
