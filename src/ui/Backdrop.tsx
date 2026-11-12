/** Soft, fixed colour washes behind every app. Decorative only, kept quieter than the UI. */
export function Backdrop() {
  return (
    <div className="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden>
      <div style={{ position: 'absolute', top: '4%', left: '-6%', width: 320, height: 320, borderRadius: '50%', background: 'radial-gradient(circle, rgba(133,177,237,0.24) 0%, transparent 70%)', filter: 'blur(60px)' }} />
      <div style={{ position: 'absolute', top: '46%', right: '-8%', width: 300, height: 300, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,205,131,0.22) 0%, transparent 70%)', filter: 'blur(60px)' }} />
      <div style={{ position: 'absolute', bottom: '-4%', left: '14%', width: 260, height: 260, borderRadius: '50%', background: 'radial-gradient(circle, rgba(126,241,179,0.14) 0%, transparent 70%)', filter: 'blur(64px)' }} />
    </div>
  )
}
