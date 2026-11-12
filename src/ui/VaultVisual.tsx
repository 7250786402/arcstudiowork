import { motion, useTransform } from 'framer-motion'
import type { Tilt } from './SummaryPanel'
import { c } from '@/escrow/theme'

const BOLTS = Array.from({ length: 10 }, (_, i) => i)
const SPOKES = [0, 60, 120]

/**
 * A 3D vault. The door is shut and the lamp glows while funds are really held in open deals,
 * and the door swings open when nothing is held. It reflects data and never animates for its own sake.
 */
export function VaultVisual({ heldCount, tilt }: { heldCount: number; tilt: Tilt }) {
  const held = heldCount > 0
  const rotateY = useTransform(tilt.x, [-0.5, 0.5], [-18, 18])
  const rotateX = useTransform(tilt.y, [-0.5, 0.5], [10, -10])

  return (
    <div aria-hidden className="relative mx-auto flex h-full w-full items-center justify-center" style={{ perspective: 820 }}>
      <div
        className="absolute"
        style={{ width: 210, height: 210, borderRadius: '50%', filter: 'blur(26px)', background: `radial-gradient(circle, rgba(172,198,233,${held ? 0.4 : 0.12}) 0%, transparent 66%)`, transition: 'background 600ms ease' }}
      />
      <motion.div style={{ position: 'relative', width: 164, height: 164, transformStyle: 'preserve-3d', rotateX, rotateY }}>
        {[-9, -6, -3].map((z) => (
          <div key={z} className="absolute inset-0" style={{ borderRadius: 38, transform: `translateZ(${z}px)`, background: '#0a1d30' }} />
        ))}
        <div
          className="absolute inset-0"
          style={{ borderRadius: 38, background: 'linear-gradient(150deg, #34567a 0%, #1b3652 46%, #0f2338 100%)', boxShadow: 'inset 0 2px 3px rgba(255,255,255,0.28), inset 0 -8px 14px rgba(0,0,0,0.4)' }}
        />
        <div className="absolute" style={{ top: 12, right: 18, width: 9, height: 9, borderRadius: '50%', background: held ? c.success : '#4a5c70', boxShadow: held ? '0 0 10px 2px rgba(141,216,159,0.7)' : 'none', transition: 'all 400ms ease' }} />
        <div
          className="absolute"
          style={{ left: 23, top: 23, width: 118, height: 118, borderRadius: '50%', transform: 'translateZ(2px)', background: 'radial-gradient(circle at 50% 40%, #050d17 0%, #0b1a2a 70%)', boxShadow: 'inset 0 4px 10px rgba(0,0,0,0.8), 0 0 0 3px #0c1f33' }}
        />
        <motion.div
          className="absolute"
          initial={false}
          animate={{ rotateY: held ? 0 : -64 }}
          transition={{ type: 'spring', stiffness: 90, damping: 16 }}
          style={{ left: 23, top: 23, width: 118, height: 118, borderRadius: '50%', transformOrigin: 'left center', transform: 'translateZ(7px)', background: 'conic-gradient(from 20deg, #5d7fa5, #8fb0d6, #4b6b8e, #7d9fc6, #5d7fa5)', boxShadow: '0 6px 14px rgba(0,0,0,0.55), inset 0 2px 2px rgba(255,255,255,0.4)' }}
        >
          <div className="absolute rounded-full" style={{ inset: 7, background: 'radial-gradient(circle at 35% 28%, #3a5d84 0%, #1c3a5a 62%, #122b45 100%)', boxShadow: 'inset 0 3px 6px rgba(255,255,255,0.18), inset 0 -5px 10px rgba(0,0,0,0.45)' }} />
          {BOLTS.map((i) => (
            <span key={i} className="absolute rounded-full" style={{ width: 6, height: 6, left: 56, top: 56, background: '#a9c2e0', boxShadow: '0 1px 1px rgba(0,0,0,0.6)', transform: `rotate(${i * 36}deg) translateY(-51px)` }} />
          ))}
          <div className="absolute rounded-full" style={{ left: 36, top: 36, width: 46, height: 46, background: 'radial-gradient(circle at 35% 30%, #d6e6f7, #7f9fc4 70%)', boxShadow: '0 3px 6px rgba(0,0,0,0.5), inset 0 1px 1px rgba(255,255,255,0.6)' }}>
            {SPOKES.map((deg) => (
              <span key={deg} className="absolute" style={{ left: 21, top: -5, width: 4, height: 56, borderRadius: 2, background: '#456687', transform: `rotate(${deg}deg)` }} />
            ))}
            <span className="absolute rounded-full" style={{ left: 16, top: 16, width: 14, height: 14, background: '#102940', boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.3)' }} />
          </div>
        </motion.div>
      </motion.div>
      <div className="absolute" style={{ bottom: 6, width: 150, height: 18, borderRadius: '50%', background: 'radial-gradient(ellipse, rgba(0,0,0,0.55), transparent 70%)', filter: 'blur(5px)' }} />
    </div>
  )
}
