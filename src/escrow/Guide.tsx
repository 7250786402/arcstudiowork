import { useState } from 'react'
import { BadgeCheck, Lock, Scale, Truck, X } from 'lucide-react'
import { c, display, glass } from './theme'

const KEY = 'escrow_guide_seen'

const STEPS = [
  { icon: Lock, title: 'Buyer locks USDC', body: 'The money moves into the contract, not to the seller yet.' },
  { icon: Truck, title: 'Seller accepts and delivers', body: 'The seller agrees to the terms first, then marks the work done.' },
  { icon: BadgeCheck, title: 'Buyer approves', body: 'Approval releases the USDC to the seller.' },
  { icon: Scale, title: 'Disagreement? Never stuck', body: 'An arbiter you both chose decides, or an agreed timer releases the money.' },
]

export function Guide() {
  const [hidden, setHidden] = useState(() => localStorage.getItem(KEY) === '1')
  if (hidden) return null
  const dismiss = () => {
    localStorage.setItem(KEY, '1')
    setHidden(true)
  }
  return (
    <section className="rounded-3xl p-5" style={glass.card} aria-label="How escrow works">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-balance" style={{ ...display, color: c.ink }}>How escrow works</p>
          <p className="mt-0.5 text-xs" style={{ color: c.muted }}>Four steps, no trust needed.</p>
        </div>
        <button onClick={dismiss} aria-label="Hide guide" className="flex size-9 items-center justify-center rounded-xl" style={glass.inner}>
          <X className="size-4" style={{ color: c.muted }} />
        </button>
      </div>
      <ol className="mt-4 space-y-3">
        {STEPS.map(({ icon: Icon, title, body }, i) => (
          <li key={title} className="flex gap-3">
            <div className="flex size-8 shrink-0 items-center justify-center rounded-xl" style={{ background: 'rgba(255,255,255,0.08)' }}>
              <Icon className="size-4" style={{ color: c.accent }} />
            </div>
            <div>
              <p className="text-sm font-medium" style={{ color: c.ink }}>{i + 1}. {title}</p>
              <p className="text-xs text-pretty" style={{ color: c.muted }}>{body}</p>
            </div>
          </li>
        ))}
      </ol>
    </section>
  )
}
