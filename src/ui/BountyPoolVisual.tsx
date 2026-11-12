import { AnimatePresence, motion, useTransform } from 'framer-motion'
import { c, display } from '@/escrow/theme'
import type { Tilt } from './SummaryPanel'

const DISC = 132
const STEP = 12
const MAX = 9
const EDGE = [-9, -6, -3]
const REEDED = 'repeating-conic-gradient(from 0deg, #2b5a86 0deg 5deg, #0b2033 5deg 10deg)'
const RIM = 'conic-gradient(from 210deg, #5fbeff, #af8ff4, #f05c6b, #ffcd83, #7ef1b3, #5fbeff)'

function Disc({ index, top }: { index: number; top: boolean }) {
  return (
    <motion.div
      className="absolute inset-0"
      style={{ transformStyle: 'preserve-3d' }}
      initial={{ z: 220, opacity: 0 }}
      animate={{ z: index * STEP, opacity: 1 }}
      exit={{ z: 220, opacity: 0 }}
      transition={{ type: 'spring', stiffness: 150, damping: 17, delay: index * 0.06 }}
    >
      {EDGE.map((z) => (
        <div key={z} style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: REEDED, transform: `translateZ(${z}px)` }} />
      ))}
      <div style={{ position: 'absolute', inset: 0, borderRadius: '50%', padding: top ? 5 : 3, background: top ? RIM : '#6f98c8' }}>
        <div
          style={{
            width: '100%', height: '100%', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: 'radial-gradient(circle at 32% 26%, #3a74aa 0%, #1a486f 42%, #0d2740 100%)',
            boxShadow: 'inset 0 2px 4px rgba(255,255,255,0.25), inset 0 -8px 14px rgba(0,0,0,0.38)',
          }}
        >
          {top && <span style={{ ...display, fontSize: 56, fontWeight: 700, color: '#e8f1fb', textShadow: '0 2px 2px rgba(0,0,0,0.45)' }}>$</span>}
        </div>
      </div>
    </motion.div>
  )
}

/** Outline coin used for the empty state: shows where the stack will grow. */
function GhostDisc({ index }: { index: number }) {
  const fade = [0.55, 0.38, 0.24][index] ?? 0.2
  return (
    <div
      style={{
        position: 'absolute', inset: 0, borderRadius: '50%', opacity: fade,
        border: '2px dashed rgba(172,198,233,0.8)', background: 'rgba(172,198,233,0.06)',
        transform: `translateZ(${index * STEP * 1.5}px)`,
      }}
    />
  )
}

/** A glowing plus coin hovering above the ghost stack: the next bounty goes here. */
function PlusDisc() {
  return (
    <motion.div
      className="absolute inset-0"
      style={{ transformStyle: 'preserve-3d' }}
      initial={{ z: 64 }}
      animate={{ z: [64, 78, 64] }}
      transition={{ duration: 3.2, repeat: Infinity, ease: 'easeInOut' }}
    >
      <div
        style={{
          position: 'absolute', inset: 6, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: 'radial-gradient(circle at 32% 26%, rgba(172,198,233,0.55), rgba(172,198,233,0.16) 70%)',
          border: '2px solid rgba(207,224,245,0.9)',
          boxShadow: '0 0 28px rgba(172,198,233,0.65), inset 0 2px 6px rgba(255,255,255,0.35)',
        }}
      >
        <span style={{ ...display, fontSize: 60, fontWeight: 600, lineHeight: 1, color: '#eaf3fd', textShadow: '0 0 16px rgba(172,198,233,0.9)' }}>+</span>
      </div>
    </motion.div>
  )
}

/**
 * Bounty Board signature visual: one coin per open bounty, stacked in a tower.
 * A new bounty drops a coin onto the stack. With no open bounties it shows an empty slot and stays still.
 */
export function BountyPoolVisual({ ids, tilt }: { ids: readonly bigint[]; tilt: Tilt }) {
  const shown = ids.slice(-MAX)
  const rotateX = useTransform(tilt.y, [-0.5, 0.5], [66, 56])
  const rotateY = useTransform(tilt.x, [-0.5, 0.5], [-9, 9])
  const empty = shown.length === 0
  return (
    <div className="relative h-full w-full">
    <div aria-hidden className="relative flex h-full w-full items-end justify-center pb-6" style={{ perspective: 900 }}>
      <div className="absolute inset-x-8 bottom-4 top-6 rounded-full" style={{ background: `radial-gradient(circle, rgba(172,198,233,${0.12 + shown.length * 0.025}) 0%, transparent 68%)`, filter: 'blur(18px)' }} />
      <motion.div className="relative" style={{ width: DISC, height: DISC, transformStyle: 'preserve-3d', rotateX, rotateY }}>
        <div style={{ position: 'absolute', inset: -14, borderRadius: '50%', background: 'radial-gradient(circle, rgba(0,0,0,0.55), transparent 68%)', transform: 'translateZ(-14px)', filter: 'blur(6px)' }} />
        {shown.length === 0 && (
          <>
            {[0, 1, 2].map((i) => <GhostDisc key={i} index={i} />)}
            <PlusDisc />
          </>
        )}
        <AnimatePresence>
          {shown.map((id, i) => (
            <Disc key={id.toString()} index={i} top={i === shown.length - 1} />
          ))}
        </AnimatePresence>
      </motion.div>
    </div>
    {empty && (
      <p className="pointer-events-none absolute inset-x-0 top-1 text-center text-xs text-pretty" style={{ color: c.muted }}>
        No open bounties yet. The first one starts the stack.
      </p>
    )}
    </div>
  )
}
