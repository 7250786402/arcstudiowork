import { useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { useAccount } from 'wagmi'
import { isAddress } from 'viem'
import { ConnectKitButton } from 'connectkit'
import { Loader2 } from 'lucide-react'
import { parseAmount } from '@/onchain-money'
import { CHAIN_ID, USDC_ADDRESS, ZERO, usd } from '@/escrowTypes'
import { CROWDFUND_ABI } from '@/crowdfundAbi'
import { c, display, glass } from '@/escrow/theme'
import { useTxFlow } from '@/escrow/useTxFlow'
import { CROWDFUND_ADDRESS } from './crowdfundTypes'

const GOALS = ['50', '100', '500', '1000']
const DURATIONS: ReadonlyArray<readonly [string, number]> = [
  ['1 hour (for a quick test)', 3600],
  ['1 day', 86400],
  ['3 days', 3 * 86400],
  ['7 days', 7 * 86400],
  ['14 days', 14 * 86400],
  ['30 days', 30 * 86400],
]
const input = 'w-full rounded-2xl px-3.5 py-3 text-sm outline-none placeholder:text-slate-400'

function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block space-y-1.5">
      <span className="text-xs font-semibold" style={{ color: c.ink }}>{label}</span>
      {children}
      {hint && <span className="block text-[11px] text-pretty" style={{ color: c.muted }}>{hint}</span>}
    </label>
  )
}

export function StartCampaignForm({ onCreated }: { onCreated: () => void }) {
  const { address, isConnected } = useAccount()
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [goal, setGoal] = useState('100')
  const [duration, setDuration] = useState(7 * 86400)
  const [beneficiary, setBeneficiary] = useState('')

  const goalRaw = useMemo(() => {
    try { const v = parseAmount(CHAIN_ID, goal).raw; return v > 0n ? v : null } catch { return null }
  }, [goal])
  const payTo = beneficiary.trim() || address || ''
  const payToOk = isAddress(payTo) && payTo !== ZERO && BigInt(payTo) >= 0x10000n && payTo.toLowerCase() !== USDC_ADDRESS.toLowerCase()
  const titleOk = title.trim().length > 0 && title.trim().length <= 100
  const descOk = description.trim().length <= 1000
  const ready = isConnected && titleOk && descOk && goalRaw !== null && payToOk

  const create = useTxFlow(onCreated)
  const submit = () => {
    if (!ready || goalRaw === null || !isAddress(payTo)) return
    void create.run((w) => w({
      address: CROWDFUND_ADDRESS, abi: CROWDFUND_ABI, functionName: 'createCampaign', chainId: CHAIN_ID,
      args: [title.trim(), description.trim(), goalRaw, BigInt(duration), payTo],
    }))
  }

  return (
    <section className="space-y-4 rounded-3xl p-5" style={glass.card}>
      <div>
        <h2 className="text-base font-bold" style={{ ...display, color: c.ink }}>Start a campaign</h2>
        <p className="mt-0.5 text-xs text-pretty" style={{ color: c.muted }}>
          All or nothing: if the goal is not reached by the deadline, every backer can take their USDC back.
        </p>
      </div>

      <Field label="Title" hint={`${title.trim().length}/100`}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="What are you raising for?" maxLength={100} className={input} style={{ ...glass.inner, color: c.ink }} />
      </Field>
      <Field label="Story" hint="Why it matters and what the money will be used for.">
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4} maxLength={1000} placeholder="Tell backers what you are building" className={`${input} resize-none`} style={{ ...glass.inner, color: c.ink }} />
      </Field>

      <Field label="Goal (USDC)" hint={goalRaw ? `You need ${usd(goalRaw)} USDC for the campaign to succeed.` : 'Enter an amount above 0.'}>
        <div className="flex flex-wrap gap-1.5">
          {GOALS.map((g) => (
            <button key={g} type="button" onClick={() => setGoal(g)} className="min-h-10 rounded-xl px-3 text-sm font-semibold tabular-nums"
              style={goal === g ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>{g}</button>
          ))}
        </div>
        <input value={goal} onChange={(e) => setGoal(e.target.value)} inputMode="decimal" className={`${input} tabular-nums`} style={{ ...glass.inner, color: c.ink }} />
      </Field>

      <Field label="Runs for">
        <select value={duration} onChange={(e) => setDuration(Number(e.target.value))} className={input} style={{ ...glass.inner, color: c.ink }}>
          {DURATIONS.map(([label, secs]) => <option key={secs} value={secs}>{label}</option>)}
        </select>
      </Field>

      <Field label="Send the money to" hint={beneficiary.trim() && !payToOk ? 'Enter a valid wallet address.' : 'Leave empty to use your connected wallet. You can change it later.'}>
        <input value={beneficiary} onChange={(e) => setBeneficiary(e.target.value)} placeholder={address ?? '0x...'} className={`${input} font-mono text-xs`} style={{ ...glass.inner, color: c.ink }} />
      </Field>

      {create.error && <p role="alert" className="text-xs" style={{ color: c.danger }}>{create.error}</p>}

      {!isConnected ? <div className="flex justify-center"><ConnectKitButton /></div> : (
        <button onClick={submit} disabled={!ready || create.busy} className="flex min-h-12 w-full items-center justify-center gap-2 rounded-2xl text-sm font-semibold text-white disabled:opacity-50" style={{ background: c.accent }}>
          {create.busy && <Loader2 className="size-4 animate-spin" />}
          {create.pending ? 'Confirm in wallet' : create.confirming ? 'Creating on Arc Testnet' : 'Start campaign'}
        </button>
      )}
    </section>
  )
}
