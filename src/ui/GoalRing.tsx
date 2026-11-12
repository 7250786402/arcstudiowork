import { useId } from 'react'
import { motion, useTransform } from 'framer-motion'
import type { Tilt } from './SummaryPanel'
import { c } from '@/escrow/theme'

interface RingProps {
  raised: bigint
  goal: bigint
  size?: number
}

/** Progress ring for raised / goal. Fill and label come straight from the two amounts. */
export function GoalRing({ raised, goal, size = 120 }: RingProps) {
  const gid = useId()
  const has = goal > 0n
  const pct = has ? Number((raised * 10000n) / goal) / 100 : 0
  const fill = Math.min(pct, 100) / 100
  const done = pct >= 100
  const R = 48

  return (
    <svg viewBox="0 0 120 120" width={size} height={size} role="img" aria-label={has ? `${Math.floor(pct)} percent funded` : 'No live campaigns'}>
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={done ? '#8dd89f' : '#cfe0f4'} />
          <stop offset="100%" stopColor={done ? '#5fbf85' : '#7fa9dc'} />
        </linearGradient>
      </defs>
      <circle cx="60" cy="60" r="58" fill="none" stroke="rgba(255,255,255,0.10)" strokeWidth="1" />
      <circle cx="60" cy="60" r={R} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="12" strokeDasharray={has ? undefined : '3 7'} strokeLinecap="round" />
      {has && (
        <motion.circle
          cx="60" cy="60" r={R} fill="none" stroke={`url(#${gid})`} strokeWidth="12" strokeLinecap="round"
          transform="rotate(-90 60 60)"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: fill }}
          transition={{ type: 'spring', stiffness: 60, damping: 16 }}
          style={{ filter: 'drop-shadow(0 0 6px rgba(172,198,233,0.55))' }}
        />
      )}
      <circle cx="60" cy="60" r="38" fill="rgba(13,27,47,0.55)" stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
      <text x="60" y={has ? 58 : 64} textAnchor="middle" fontSize={has ? 22 : 18} fontWeight="700" fill={c.ink} style={{ fontFamily: "'Space Grotesk', sans-serif" }}>
        {has ? `${Math.floor(pct)}%` : '--'}
      </text>
      {has && <text x="60" y="74" textAnchor="middle" fontSize="9" fill={c.muted} style={{ letterSpacing: '0.08em' }}>FUNDED</text>}
    </svg>
  )
}

/** Large, tilting version for the Crowdfund summary panel. */
export function GoalVisual({ raised, goal, tilt }: RingProps & { tilt: Tilt }) {
  const rotateY = useTransform(tilt.x, [-0.5, 0.5], [-22, 22])
  const rotateX = useTransform(tilt.y, [-0.5, 0.5], [16, -16])
  return (
    <div aria-hidden className="relative flex h-full w-full items-center justify-center" style={{ perspective: 820 }}>
      <div className="absolute" style={{ width: 220, height: 220, borderRadius: '50%', filter: 'blur(28px)', background: `radial-gradient(circle, rgba(172,198,233,${goal > 0n ? 0.34 : 0.1}) 0%, transparent 66%)` }} />
      <motion.div style={{ position: 'relative', width: 178, height: 178, transformStyle: 'preserve-3d', rotateX, rotateY }}>
        {[-10, -7, -4].map((z) => (
          <div key={z} className="absolute inset-0" style={{ borderRadius: '50%', transform: `translateZ(${z}px)`, background: '#0a1d30' }} />
        ))}
        <div className="absolute inset-0" style={{ borderRadius: '50%', background: 'linear-gradient(150deg, #2b4a6c 0%, #14304c 60%, #0d2036 100%)', boxShadow: 'inset 0 2px 3px rgba(255,255,255,0.25), inset 0 -8px 14px rgba(0,0,0,0.45)' }} />
        <div className="absolute inset-0" style={{ transform: 'translateZ(8px)' }}>
          <GoalRing raised={raised} goal={goal} size={178} />
        </div>
      </motion.div>
      <div className="absolute" style={{ bottom: 6, width: 150, height: 16, borderRadius: '50%', background: 'radial-gradient(ellipse, rgba(0,0,0,0.55), transparent 70%)', filter: 'blur(5px)' }} />
    </div>
  )
}
