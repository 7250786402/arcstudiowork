import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { Check, ChevronDown, Copy, ExternalLink, Share2 } from 'lucide-react'
import { buildAddressExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID, STATUS, STATUS_LABEL, ZERO, fmtDate, short, usd } from '@/escrowTypes'
import type { Addr, Deal } from '@/escrowTypes'
import { buildShareLink } from '@/lib/share'
import { c, display, glass } from './theme'
import { DealActions } from './DealActions'
import { DealTimeline } from './DealTimeline'

const STEPS = ['Funded', 'Accepted', 'Delivered', 'Paid']

function useNow() {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))
  useEffect(() => {
    const t = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 30000)
    return () => clearInterval(t)
  }, [])
  return now
}

function stepIndex(status: number) {
  if (status === STATUS.Funded) return 0
  if (status === STATUS.Accepted) return 1
  if (status === STATUS.Delivered || status === STATUS.Disputed) return 2
  return 3
}

function tone(status: number) {
  if (status === STATUS.Released || status === STATUS.Resolved) return { bg: 'rgba(26,128,71,0.12)', fg: c.success }
  if (status === STATUS.Disputed) return { bg: 'rgba(192,57,43,0.1)', fg: c.danger }
  if (status === STATUS.Refunded) return { bg: 'rgba(92,107,124,0.12)', fg: c.muted }
  return { bg: 'rgba(18,45,69,0.08)', fg: c.accent }
}

function Party({ label, addr, me }: { label: string; addr: Addr; me?: Addr }) {
  if (addr === ZERO) return null
  return (
    <div className="flex items-center justify-between text-xs">
      <span style={{ color: c.muted }}>{label}</span>
      <a href={buildAddressExplorerUrl(CHAIN_ID, addr)} target="_blank" rel="noopener noreferrer" className="flex items-center gap-1 font-medium tabular-nums" style={{ color: c.ink }}>
        {short(addr)}{me?.toLowerCase() === addr.toLowerCase() ? ' (you)' : ''}<ExternalLink className="size-3" style={{ color: c.subtle }} />
      </a>
    </div>
  )
}

/** The link is resolved once per deal; Copy and Share stay disabled until it is ready. */
function ShareRow({ deal }: { deal: Deal }) {
  const [link, setLink] = useState('')
  const [copied, setCopied] = useState(false)
  useEffect(() => {
    let live = true
    void buildShareLink(`/?deal=${deal.id.toString()}`).then((l) => { if (live) setLink(l) })
    return () => { live = false }
  }, [deal.id])

  const copy = async () => {
    await navigator.clipboard.writeText(link)
    setCopied(true)
    setTimeout(() => setCopied(false), 1800)
  }
  const share = async () => {
    try { await navigator.share({ title: deal.title, text: `Escrow deal: ${deal.title}`, url: link }) } catch { await copy() }
  }

  return (
    <div className="flex gap-2">
      <button onClick={() => void copy()} disabled={!link}
        className="flex min-h-11 flex-1 items-center justify-center gap-2 rounded-2xl text-sm font-semibold transition-transform active:scale-[0.98] disabled:opacity-40"
        style={{ color: c.ink, ...glass.inner }}>
        {copied ? <Check className="size-4" style={{ color: c.success }} /> : <Copy className="size-4" />}
        {copied ? 'Link copied' : 'Copy deal link'}
      </button>
      {typeof navigator.share === 'function' && (
        <button onClick={() => void share()} disabled={!link} aria-label="Share deal"
          className="flex min-h-11 w-12 items-center justify-center rounded-2xl transition-transform active:scale-[0.98] disabled:opacity-40" style={glass.inner}>
          <Share2 className="size-4" style={{ color: c.ink }} />
        </button>
      )}
    </div>
  )
}

export function DealCard({ deal, me, onChanged, defaultOpen = false, index = 0 }: { deal: Deal; me?: Addr; onChanged: () => void; defaultOpen?: boolean; index?: number }) {
  const [open, setOpen] = useState(defaultOpen)
  const now = useNow()
  const meL = me?.toLowerCase()
  const role = meL === deal.buyer.toLowerCase() ? 'Buyer' : meL === deal.seller.toLowerCase() ? 'Seller' : deal.arbiter !== ZERO && meL === deal.arbiter.toLowerCase() ? 'Arbiter' : ''
  const t = tone(deal.status)
  const idx = stepIndex(deal.status)
  const live = deal.status <= STATUS.Delivered || deal.status === STATUS.Disputed

  return (
    <motion.article className="lift overflow-hidden rounded-3xl" style={glass.card}
      initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.24, delay: Math.min(index, 5) * 0.04 }}>
      <button onClick={() => setOpen((v) => !v)} aria-expanded={open} className="w-full p-4 text-left">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold" style={{ ...display, color: c.ink }}>{deal.title}</p>
            <p className="mt-0.5 text-xs" style={{ color: c.muted }}>{role ? `You are the ${role.toLowerCase()}` : 'Deal'} · #{deal.id.toString()}</p>
          </div>
          <div className="flex items-center gap-2">
            <span className="rounded-full px-2.5 py-1 text-[11px] font-semibold" style={{ background: t.bg, color: t.fg }}>{STATUS_LABEL[deal.status]}</span>
            <ChevronDown className="size-4 transition-transform" style={{ color: c.subtle, transform: open ? 'rotate(180deg)' : 'none' }} />
          </div>
        </div>
        <div className="mt-3 flex items-baseline gap-1">
          <span className="text-3xl font-bold tabular-nums" style={{ ...display, color: c.ink }}>{usd(deal.amount)}</span>
          <span className="text-sm font-medium" style={{ color: c.subtle }}>USDC</span>
        </div>
        {live && (
          <div className="mt-3 flex gap-1.5" aria-label={`Step ${idx + 1} of 4`}>
            {STEPS.map((s, i) => (
              <div key={s} className="flex-1">
                <div className="h-1 rounded-full" style={{ background: i <= idx ? c.accent : 'rgba(18,45,69,0.1)' }} />
                <p className="mt-1 flex items-center gap-0.5 text-[10px] font-medium" style={{ color: i <= idx ? c.ink : c.subtle }}>
                  {i < idx && <Check className="size-2.5" style={{ color: c.success }} />}{s}
                </p>
              </div>
            ))}
          </div>
        )}
      </button>

      {open && (
        <motion.div className="space-y-4 px-4 pb-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.2 }}>
          <div className="rounded-2xl p-3.5" style={glass.inner}>
            <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>Agreed terms</p>
            <p className="mt-1 whitespace-pre-wrap text-sm text-pretty" style={{ color: c.ink }}>{deal.terms}</p>
          </div>
          <div className="space-y-1.5 rounded-2xl p-3.5" style={glass.inner}>
            <Party label="Buyer" addr={deal.buyer} me={me} />
            <Party label="Seller" addr={deal.seller} me={me} />
            <Party label="Payout to" addr={deal.sellerPayout} me={me} />
            <Party label="Arbiter" addr={deal.arbiter} me={me} />
            <div className="flex items-center justify-between text-xs">
              <span style={{ color: c.muted }}>Deliver by</span>
              <span className="font-medium" style={{ color: c.ink }}>{fmtDate(deal.deliverBy)}</span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span style={{ color: c.muted }}>Auto-release</span>
              <span className="font-medium" style={{ color: c.ink }}>{deal.reviewWindow === 0n ? 'Off' : `${Number(deal.reviewWindow) / 86400} days after delivery`}</span>
            </div>
          </div>
          <DealActions deal={deal} me={me} now={now} onChanged={onChanged} />
          <div className="rounded-2xl p-3.5" style={glass.inner}><DealTimeline deal={deal} /></div>
          <ShareRow deal={deal} />
        </motion.div>
      )}
    </motion.article>
  )
}
