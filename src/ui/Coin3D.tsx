import { motion } from 'framer-motion'
import type { MotionValue } from 'framer-motion'
import { display } from '@/escrow/theme'

const SIZE = 84
// Z offsets of the stacked discs that make the coin's rim look thick when it tilts.
const RIM_LAYERS = [-5, -4, -3, -2, -1, 0]

/**
 * A decorative CSS 3D coin. It only tilts with the pointer (see HeroCard) and never carries data.
 */
export function Coin3D({ rotateX, rotateY }: { rotateX: MotionValue<number>; rotateY: MotionValue<number> }) {
  return (
    <div aria-hidden className="pointer-events-none relative" style={{ width: SIZE, height: SIZE, perspective: 520 }}>
      <motion.div style={{ position: 'relative', width: SIZE, height: SIZE, transformStyle: 'preserve-3d', rotateX, rotateY }}>
        {RIM_LAYERS.map((z) => (
          <div
            key={z}
            style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: '#0b2033', transform: `translateZ(${z}px)` }}
          />
        ))}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: '50%',
            padding: 4,
            transform: 'translateZ(2px)',
            background: 'conic-gradient(from 210deg, #5fbeff, #af8ff4, #f05c6b, #ffcd83, #7ef1b3, #5fbeff)',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: '100%',
              height: '100%',
              borderRadius: '50%',
              background: 'radial-gradient(circle at 30% 24%, #2d6296 0%, #17426a 38%, #0f2a43 100%)',
              boxShadow: 'inset 0 2px 4px rgba(255,255,255,0.25), inset 0 -6px 10px rgba(0,0,0,0.35)',
            }}
          >
            <span style={{ ...display, fontSize: 38, fontWeight: 700, color: '#e8f1fb', textShadow: '0 1px 0 rgba(255,255,255,0.35), 0 -1px 2px rgba(0,0,0,0.5)' }}>$</span>
          </div>
        </div>
      </motion.div>
      <div
        style={{ position: 'absolute', left: '12%', right: '12%', bottom: -12, height: 12, borderRadius: '50%', background: 'radial-gradient(ellipse, rgba(18,45,69,0.3), transparent 70%)', filter: 'blur(4px)' }}
      />
    </div>
  )
}
