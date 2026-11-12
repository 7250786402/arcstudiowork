import { useId, useMemo, useRef, useState } from 'react'
import type { PointerEvent } from 'react'
import { motion } from 'framer-motion'
import { c } from '@/escrow/theme'
import type { SeriesPoint } from '@/lib/series'

const W = 320
const H = 96
const PX = 6
const PT = 10
const PB = 12

const dateLabel = (t: number) => new Date(t * 1000).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
const money = (v: number) => v.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })

/**
 * Step chart of a running USDC total built from real onchain events.
 * Hover or touch to read a point. With no events it shows an empty grid and says so.
 */
export function ActivityChart({ title, points, nowSec }: { title: string; points: SeriesPoint[]; nowSec: number }) {
  const gid = useId()
  const svgRef = useRef<SVGSVGElement>(null)
  const [hover, setHover] = useState<number | null>(null)

  const geo = useMemo(() => {
    if (points.length === 0) return null
    const t0 = points[0]?.t ?? 0
    const last = points[points.length - 1]?.t ?? t0
    const t1 = Math.max(nowSec, last, t0 + 3600)
    const vmax = Math.max(...points.map((p) => p.v), 0.01) * 1.25
    const x = (t: number) => PX + ((t - t0) / (t1 - t0)) * (W - 2 * PX)
    const y = (v: number) => PT + (1 - v / vmax) * (H - PT - PB)
    let line = `M ${x(t0)} ${y(points[0]?.v ?? 0)}`
    for (const p of points.slice(1)) line += ` H ${x(p.t)} V ${y(p.v)}`
    line += ` H ${x(t1)}`
    const area = `${line} V ${H - PB} H ${x(t0)} Z`
    return { x, y, line, area, t0 }
  }, [points, nowSec])

  const onMove = (e: PointerEvent<SVGSVGElement>) => {
    if (!geo || !svgRef.current) return
    const r = svgRef.current.getBoundingClientRect()
    const sx = ((e.clientX - r.left) / r.width) * W
    let idx = 0
    points.forEach((p, i) => {
      if (geo.x(p.t) <= sx) idx = i
    })
    setHover(idx)
  }

  const shown = hover !== null ? points[hover] : points[points.length - 1]
  const headline = shown ? `${money(shown.v)} USDC` : '--'
  const sub = hover !== null && shown ? dateLabel(shown.t) : shown ? 'Latest' : 'No activity yet'
  const gridY = [0.25, 0.5, 0.75].map((f) => PT + f * (H - PT - PB))

  return (
    <div className="mt-4 rounded-2xl p-3" style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)' }}>
      <div className="flex items-baseline justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.08em]" style={{ color: c.muted }}>{title}</p>
        <p className="text-right text-xs tabular-nums" style={{ color: c.ink }}>
          <span className="font-semibold">{headline}</span>
          <span style={{ color: c.subtle }}> · {sub}</span>
        </p>
      </div>
      <svg
        ref={svgRef}
        viewBox={`0 0 ${W} ${H}`}
        className="mt-2 w-full touch-pan-y"
        role="img"
        aria-label={shown ? `${title}: ${headline} after ${points.length} events` : `${title}: no activity yet`}
        onPointerMove={onMove}
        onPointerLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id={`${gid}-fill`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#acc6e9" stopOpacity="0.42" />
            <stop offset="100%" stopColor="#acc6e9" stopOpacity="0" />
          </linearGradient>
        </defs>
        {gridY.map((gy) => <line key={gy} x1={PX} x2={W - PX} y1={gy} y2={gy} stroke="rgba(255,255,255,0.07)" strokeDasharray="2 4" />)}
        <line x1={PX} x2={W - PX} y1={H - PB} y2={H - PB} stroke="rgba(255,255,255,0.14)" />
        {!geo && <text x={W / 2} y={H / 2 + 4} textAnchor="middle" fontSize="11" fill={c.subtle}>Activity shows up here once someone uses it</text>}
        {geo && (
          <>
            <motion.path d={geo.area} fill={`url(#${gid}-fill)`} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.8, delay: 0.3 }} />
            <motion.path d={geo.line} fill="none" stroke="#acc6e9" strokeWidth="2" strokeLinejoin="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.9, ease: 'easeOut' }} />
            {points.slice(-24).map((p) => <circle key={`${p.t}-${p.v}`} cx={geo.x(p.t)} cy={geo.y(p.v)} r="2.5" fill="#0d1b2f" stroke="#cfe0f5" strokeWidth="1.5" />)}
            {hover !== null && shown && (
              <>
                <motion.line y1={PT} y2={H - PB} stroke="rgba(207,224,245,0.5)" strokeWidth="1" initial={false} animate={{ x1: geo.x(shown.t), x2: geo.x(shown.t) }} transition={{ type: 'spring', stiffness: 380, damping: 32 }} />
                <motion.circle r="9" fill="rgba(172,198,233,0.22)" initial={false} animate={{ cx: geo.x(shown.t), cy: geo.y(shown.v) }} transition={{ type: 'spring', stiffness: 380, damping: 32 }} />
                <motion.circle r="4.5" fill="#acc6e9" stroke="#0d1b2f" strokeWidth="2" initial={false} animate={{ cx: geo.x(shown.t), cy: geo.y(shown.v) }} transition={{ type: 'spring', stiffness: 380, damping: 32 }} />
              </>
            )}
          </>
        )}
      </svg>
      {geo && (
        <div className="mt-1 flex justify-between text-[10px]" style={{ color: c.subtle }}>
          <span>{dateLabel(geo.t0)}</span>
          <span>Now</span>
        </div>
      )}
    </div>
  )
}
