import { c } from '@/escrow/theme'

const GRID = 'linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px)'
const FADE = 'radial-gradient(ellipse 80% 60% at 50% 0%, #000 0%, transparent 72%)'

/** The dark aurora behind every app: deep navy, two slow glows and a faint grid. Decorative only. */
export function Backdrop() {
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden>
      <div className="absolute inset-0" style={{ background: c.bg }} />
      <div className="drift-a absolute" style={{ top: '-14%', left: '-10%', width: 620, height: 620, borderRadius: '50%', background: 'radial-gradient(circle, rgba(88,146,228,0.34) 0%, transparent 68%)', filter: 'blur(70px)' }} />
      <div className="drift-b absolute" style={{ bottom: '-16%', right: '-12%', width: 560, height: 560, borderRadius: '50%', background: 'radial-gradient(circle, rgba(126,241,179,0.14) 0%, transparent 68%)', filter: 'blur(76px)' }} />
      <div className="absolute" style={{ top: '38%', right: '6%', width: 340, height: 340, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,205,131,0.09) 0%, transparent 70%)', filter: 'blur(70px)' }} />
      <div className="absolute inset-0" style={{ backgroundImage: GRID, backgroundSize: '56px 56px', WebkitMaskImage: FADE, maskImage: FADE }} />
    </div>
  )
}
