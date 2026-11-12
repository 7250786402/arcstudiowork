import { useCallback, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { erc20Abi, isAddress } from 'viem'
import { ConnectKitButton } from 'connectkit'
import { Loader2, ShieldCheck } from 'lucide-react'
import { parseAmount } from '@/onchain-money'
import { ESCROW_ABI } from '@/escrowAbi'
import { CHAIN_ID, DAY, ESCROW_ADDRESS, USDC_ADDRESS, ZERO, usd } from '@/escrowTypes'
import type { Addr } from '@/escrowTypes'
import { c, display, glass } from './theme'
import { useTxFlow } from './useTxFlow'

const DEADLINES = [
  { label: '1 day', days: 1 },
  { label: '3 days', days: 3 },
  { label: '1 week', days: 7 },
  { label: '2 weeks', days: 14 },
  { label: '1 month', days: 30 },
]
const WINDOWS = [
  { label: 'None', days: 0 },
  { label: '3 days', days: 3 },
  { label: '7 days', days: 7 },
  { label: '14 days', days: 14 },
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

function Chips<T extends number>({ items, value, onPick }: { items: { label: string; days: T }[]; value: T; onPick: (d: T) => void }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {items.map((i) => (
        <button key={i.label} type="button" onClick={() => onPick(i.days)}
          className="min-h-9 rounded-xl px-3 text-xs font-semibold transition-colors"
          style={value === i.days ? { background: c.accent, color: '#fff' } : { color: c.muted, ...glass.inner }}>
          {i.label}
        </button>
      ))}
    </div>
  )
}

export function NewDealForm({ onCreated }: { onCreated: () => void }) {
  const { address, isConnected } = useAccount()
  const [seller, setSeller] = useState('')
  const [amount, setAmount] = useState('')
  const [title, setTitle] = useState('')
  const [terms, setTerms] = useState('')
  const [days, setDays] = useState(7)
  const [arbiter, setArbiter] = useState('')
  const [windowDays, setWindowDays] = useState(0)

  const amountRaw = useMemo(() => {
    try { return amount ? parseAmount(CHAIN_ID, amount).raw : null } catch { return null }
  }, [amount])

  const { data: balance } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [address ?? ZERO],
    chainId: CHAIN_ID, query: { enabled: !!address, refetchInterval: 10000 },
  })
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: USDC_ADDRESS, abi: erc20Abi, functionName: 'allowance', args: [address ?? ZERO, ESCROW_ADDRESS],
    chainId: CHAIN_ID, query: { enabled: !!address },
  })

  const onApproved = useCallback(() => { void refetchAllowance() }, [refetchAllowance])
  const approve = useTxFlow(onApproved)
  const create = useTxFlow(onCreated)

  const sellerOk = isAddress(seller) && seller.toLowerCase() !== address?.toLowerCase()
  const arbiterSet = arbiter.trim() !== ''
  const arbiterOk = !arbiterSet || (isAddress(arbiter) && arbiter.toLowerCase() !== address?.toLowerCase() && arbiter.toLowerCase() !== seller.toLowerCase())
  const safeguardOk = arbiterSet || windowDays > 0
  const enough = amountRaw !== null && balance !== undefined && balance >= amountRaw
  const needsApproval = amountRaw !== null && (allowance ?? 0n) < amountRaw
  const formOk = sellerOk && arbiterOk && safeguardOk && amountRaw !== null && amountRaw > 0n && title.trim() !== '' && terms.trim() !== ''

  const doApprove = () => {
    if (amountRaw === null) return
    void approve.run((w) => w({ address: USDC_ADDRESS, abi: erc20Abi, functionName: 'approve', args: [ESCROW_ADDRESS, amountRaw], chainId: CHAIN_ID }))
  }
  const doCreate = () => {
    if (amountRaw === null) return
    const deliverBy = BigInt(Math.floor(Date.now() / 1000) + days * DAY)
    void create.run((w) => w({
      address: ESCROW_ADDRESS, abi: ESCROW_ABI, functionName: 'createDeal', chainId: CHAIN_ID,
      args: [seller as Addr, amountRaw, title.trim(), terms.trim(), deliverBy, (arbiterSet ? arbiter : ZERO) as Addr, BigInt(windowDays * DAY)],
    }))
  }

  const inputCls = 'w-full bg-transparent text-sm outline-none placeholder:text-slate-400'
  const err = approve.error || create.error

  return (
    <section className="space-y-3">
      <div className="rounded-3xl p-5" style={glass.card}>
        <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Amount to hold</p>
        <div className="mt-1 flex items-baseline gap-1.5">
          <input inputMode="decimal" value={amount} placeholder="0.00"
            onChange={(e) => { const v = e.target.value; if (/^\d*\.?\d{0,6}$/.test(v)) setAmount(v) }}
            className="w-full bg-transparent text-4xl font-bold tabular-nums outline-none placeholder:text-slate-300"
            style={{ ...display, color: c.ink }} />
          <span className="text-lg font-medium" style={{ color: c.subtle }}>USDC</span>
        </div>
        <div className="mt-3 flex items-center justify-between text-xs" style={{ color: c.muted }}>
          <div className="flex gap-1.5">
            {[10, 25, 50, 100].map((v) => (
              <button key={v} type="button" onClick={() => setAmount(String(v))} className="min-h-9 rounded-xl px-3 font-semibold" style={glass.inner}>${v}</button>
            ))}
          </div>
          <span className="tabular-nums">{balance !== undefined ? `Balance ${usd(balance)}` : ''}</span>
        </div>
      </div>

      <Field label="Seller wallet" hint={seller && !sellerOk ? 'Enter a valid address that is not your own.' : 'The person who will do the work or deliver.'}>
        <input value={seller} onChange={(e) => setSeller(e.target.value.trim())} placeholder="0x..." className={inputCls} style={{ color: c.ink }} />
      </Field>
      <Field label="What is this deal for?">
        <input value={title} maxLength={80} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Logo design for my shop" className={inputCls} style={{ color: c.ink }} />
      </Field>
      <Field label="Agreed terms" hint="Write exactly what counts as done. Both sides see this before the seller accepts.">
        <textarea value={terms} rows={3} maxLength={500} onChange={(e) => setTerms(e.target.value)} placeholder="Deliverables, format, number of revisions..." className={`${inputCls} resize-none`} style={{ color: c.ink }} />
      </Field>
      <Field label="Seller must deliver within">
        <Chips items={DEADLINES.map((d) => ({ label: d.label, days: d.days }))} value={days} onPick={setDays} />
      </Field>

      <div className="rounded-3xl p-4" style={glass.card}>
        <div className="mb-3 flex items-center gap-2">
          <ShieldCheck className="size-4" style={{ color: c.success }} />
          <p className="text-sm font-semibold" style={{ color: c.ink }}>If you disagree or go quiet</p>
        </div>
        <p className="mb-3 text-xs text-pretty" style={{ color: c.muted }}>Pick at least one, so funds can never stay stuck.</p>
        <div className="space-y-3">
          <Field label="Arbiter (optional)" hint={arbiterSet && !arbiterOk ? 'Must be a valid address, different from you and the seller.' : 'A trusted third person who settles disputes.'}>
            <input value={arbiter} onChange={(e) => setArbiter(e.target.value.trim())} placeholder="0x..." className={inputCls} style={{ color: c.ink }} />
          </Field>
          <Field label="Auto-release to seller after delivery" hint="If you do not respond within this time after delivery, the seller can collect.">
            <Chips items={WINDOWS} value={windowDays} onPick={setWindowDays} />
          </Field>
        </div>
        {!safeguardOk && <p className="mt-3 text-xs font-medium" style={{ color: c.warn }}>Add an arbiter or an auto-release time to continue.</p>}
      </div>

      {err && <p className="rounded-2xl px-4 py-3 text-sm" style={{ color: c.danger, background: 'rgba(192,57,43,0.08)' }}>{err}</p>}
      {amountRaw !== null && balance !== undefined && !enough && (
        <p className="text-xs font-medium" style={{ color: c.danger }}>Your balance is lower than this amount. Use Get test USDC in the sidebar.</p>
      )}

      {!isConnected ? (
        <div className="flex justify-center"><ConnectKitButton /></div>
      ) : needsApproval ? (
        <button disabled={!formOk || !enough || approve.busy} onClick={doApprove}
          className="min-h-12 w-full rounded-2xl text-sm font-semibold text-white transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40"
          style={{ background: c.accent }}>
          {approve.pending ? <Spin>Confirm in wallet...</Spin> : approve.confirming ? <Spin>Allowing USDC...</Spin> : 'Step 1 of 2: Allow USDC'}
        </button>
      ) : (
        <button disabled={!formOk || !enough || create.busy} onClick={doCreate}
          className="min-h-12 w-full rounded-2xl text-sm font-semibold text-white transition-all active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-40"
          style={{ background: c.success }}>
          {create.pending ? <Spin>Confirm in wallet...</Spin> : create.confirming ? <Spin>Funding escrow...</Spin> : `Step 2 of 2: Lock ${amount || '0'} USDC in escrow`}
        </button>
      )}
    </section>
  )
}

function Spin({ children }: { children: ReactNode }) {
  return <span className="flex items-center justify-center gap-2"><Loader2 className="size-4 animate-spin" />{children}</span>
}
