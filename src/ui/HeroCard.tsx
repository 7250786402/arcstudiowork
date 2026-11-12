import type { PointerEvent, ReactNode } from 'react'
import { motion, useMotionValue, useReducedMotion, useSpring, useTransform } from 'framer-motion'
import { RefreshCw } from 'lucide-react'
import { c, display, glass } from '@/escrow/theme'
import { Coin3D } from './Coin3D'

interface HeroCardProps {
  label: string
  amount: string
  unit?: string
  caption: string
  refreshLabel: string
  onRefresh: () => void
  children?: ReactNode
}

/**
 * The one dominant object on each screen: a big live number on a raised glass card.
 * On devices with a pointer the card and its coin tilt gently toward the cursor.
 */
export function HeroCard({ label, amount, unit = 'USDC', caption, refreshLabel, onRefresh, children }: HeroCardProps) {
  const reduce = useReducedMotion()
  const px = useMotionValue(0)
  const py = useMotionValue(0)
  const sx = useSpring(px, { stiffness: 200, damping: 22 })
  const sy = useSpring(py, { stiffness: 200, damping: 22 })
  const cardRotateY = useTransform(sx, [-0.5, 0.5], [-3.5, 3.5])
  const cardRotateX = useTransform(sy, [-0.5, 0.5], [3, -3])
  // The coin rests slightly turned so it reads as 3D even before any pointer movement.
  const coinRotateY = useTransform(sx, [-0.5, 0.5], [-42, 10])
  const coinRotateX = useTransform(sy, [-0.5, 0.5], [24, -12])

  const onMove = (e: PointerEvent<HTMLElement>) => {
    if (reduce) return
    const r = e.currentTarget.getBoundingClientRect()
    px.set((e.clientX - r.left) / r.width - 0.5)
    py.set((e.clientY - r.top) / r.height - 0.5)
  }
  const onLeave = () => {
    px.set(0)
    py.set(0)
  }

  return (
    <div style={{ perspective: 1100 }}>
      <motion.section
        onPointerMove={onMove}
        onPointerLeave={onLeave}
        className="relative overflow-hidden rounded-3xl p-5"
        style={{ ...glass.hero, rotateX: cardRotateX, rotateY: cardRotateY }}
      >
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{ background: 'linear-gradient(125deg, rgba(255,255,255,0.75) 0%, rgba(255,255,255,0) 38%)' }}
        />
        <div className="relative flex items-start justify-between gap-3">
          <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>{label}</p>
          <button onClick={onRefresh} aria-label={refreshLabel} className="flex size-11 shrink-0 items-center justify-center rounded-xl" style={glass.inner}>
            <RefreshCw className="size-4" style={{ color: c.muted }} />
          </button>
        </div>
        <div className="relative -mt-2 flex items-center justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-baseline gap-1.5">
              <span className="truncate text-4xl font-bold tabular-nums" style={{ ...display, color: c.ink }}>{amount}</span>
              <span className="text-lg font-medium" style={{ color: c.subtle }}>{unit}</span>
            </div>
            <p className="mt-1.5 text-xs text-pretty" style={{ color: c.muted }}>{caption}</p>
          </div>
          <div className="shrink-0 pr-1"><Coin3D rotateX={coinRotateX} rotateY={coinRotateY} /></div>
        </div>
        {children && <div className="relative mt-3">{children}</div>}
      </motion.section>
    </div>
  )
}
