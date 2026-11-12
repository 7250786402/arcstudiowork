import type { PointerEvent, ReactNode } from 'react'
import { motion, useMotionValue, useReducedMotion, useSpring, useTransform } from 'framer-motion'
import type { MotionValue } from 'framer-motion'
import { RefreshCw } from 'lucide-react'
import { c, display, glass } from '@/escrow/theme'
import { CountUp } from './CountUp'
import { formatAgo, useLastSync } from './useLastSync'
import { AnimatedNumber } from './AnimatedNumber'

/** Pointer position over the panel, eased, from -0.5 (left/top) to 0.5 (right/bottom). */
export interface Tilt {
  x: MotionValue<number>
  y: MotionValue<number>
}

export interface SummaryStat {
  label: string
  value: string
  tone?: 'default' | 'success'
}

interface SummaryPanelProps {
  eyebrow: string
  /** Raw 6-decimal USDC units, or null while the first read is loading. */
  amountRaw: bigint | null
  formatAmount: (raw: bigint) => string
  caption: string
  visual: (tilt: Tilt) => ReactNode
  /** Optional chart shown under the caption. */
  chart?: ReactNode
  stats?: SummaryStat[]
  refreshLabel: string
  onRefresh: () => void
  children?: ReactNode
}

/**
 * The one dominant object on each app: a live number with its signature 3D visual.
 * On desktop it is the sticky left panel; on a phone it sits at the top.
 * The card and visual tilt toward a mouse pointer (not on touch, not under reduced motion).
 */
export function SummaryPanel({ eyebrow, amountRaw, formatAmount, caption, visual, chart, stats, refreshLabel, onRefresh, children }: SummaryPanelProps) {
  const reduce = useReducedMotion()
  const syncedAgo = useLastSync()
  const px = useMotionValue(0)
  const py = useMotionValue(0)
  const x = useSpring(px, { stiffness: 190, damping: 24 })
  const y = useSpring(py, { stiffness: 190, damping: 24 })
  const rotateY = useTransform(x, [-0.5, 0.5], [-3, 3])
  const rotateX = useTransform(y, [-0.5, 0.5], [2.5, -2.5])

  const onMove = (e: PointerEvent<HTMLElement>) => {
    if (reduce || e.pointerType !== 'mouse') return
    const r = e.currentTarget.getBoundingClientRect()
    px.set((e.clientX - r.left) / r.width - 0.5)
    py.set((e.clientY - r.top) / r.height - 0.5)
  }
  const onLeave = () => {
    px.set(0)
    py.set(0)
  }

  return (
    <div style={{ perspective: 1200 }}>
      <motion.section
        onPointerMove={onMove}
        onPointerLeave={onLeave}
        className="relative overflow-hidden rounded-[28px] p-5"
        style={{ ...glass.hero, rotateX, rotateY }}
      >
        <span aria-hidden className="hero-edge" />
        <div className="flex items-start justify-between gap-3">
          <div className="flex flex-col items-start gap-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.1em]" style={{ color: c.muted }}>{eyebrow}</p>
            <span className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.08em]"
              style={{ background: amountRaw === null ? 'rgba(255,255,255,0.06)' : 'rgba(141,216,159,0.12)', color: amountRaw === null ? c.subtle : c.success }}>
              <span aria-hidden className={`size-1.5 rounded-full ${amountRaw === null ? '' : 'live-dot'}`} style={{ background: amountRaw === null ? c.subtle : c.success }} />
              {amountRaw === null ? 'Syncing' : syncedAgo === null ? 'Live on Arc Testnet' : `Live on Arc Testnet · synced ${formatAgo(syncedAgo)}`}
            </span>
          </div>
          <button onClick={onRefresh} aria-label={refreshLabel} className="btn flex size-11 shrink-0 items-center justify-center rounded-xl" style={glass.inner}>
            <RefreshCw className="size-4" style={{ color: c.muted }} />
          </button>
        </div>
        <div className="relative -mt-3 h-44 lg:h-56">{visual({ x, y })}</div>
        <div className="flex items-baseline gap-2">
          <span className="truncate text-5xl font-bold tabular-nums" style={{ ...display, backgroundImage: 'linear-gradient(180deg, #ffffff 25%, #a9c3e4 100%)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent' }}>
            <CountUp raw={amountRaw} format={formatAmount} />
          </span>
          <span className="text-lg font-medium" style={{ color: c.subtle }}>USDC</span>
        </div>
        <p className="mt-1.5 text-sm text-pretty" style={{ color: c.muted }}>{caption}</p>
        {chart}
        {stats && stats.length > 0 && (
          <dl className="mt-4 grid gap-2" style={{ gridTemplateColumns: `repeat(${stats.length}, minmax(0, 1fr))` }}>
            {stats.map((s) => (
              <div key={s.label} className="rounded-2xl p-3" style={glass.inner}>
                <dt className="text-[11px]" style={{ color: c.muted }}>{s.label}</dt>
                <dd className="mt-0.5 text-base font-semibold tabular-nums" style={{ ...display, color: s.tone === 'success' ? c.success : c.ink }}><AnimatedNumber value={s.value} /></dd>
              </div>
            ))}
          </dl>
        )}
        {children && <div className="mt-4">{children}</div>}
      </motion.section>
    </div>
  )
}
