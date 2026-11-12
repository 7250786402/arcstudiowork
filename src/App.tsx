import { useState } from 'react'
import { LayoutGroup, MotionConfig, motion } from 'framer-motion'
import BountyApp from './bounty/BountyApp'
import CrowdfundApp from './crowdfund/CrowdfundApp'
import EscrowApp from './escrow/EscrowApp'
import { c, glass } from './escrow/theme'
import { Backdrop } from './ui/Backdrop'

type AppId = 'bounty' | 'escrow' | 'crowdfund'

const APPS: { id: AppId; label: string }[] = [
  { id: 'bounty', label: 'Bounty Board' },
  { id: 'escrow', label: 'Escrow' },
  { id: 'crowdfund', label: 'Crowdfund' },
]

function initialApp(): AppId {
  const q = new URLSearchParams(window.location.search)
  if (q.get('deal') !== null) return 'escrow'
  const a = q.get('app')
  return a === 'escrow' || a === 'crowdfund' ? a : 'bounty'
}

export default function App() {
  const [app, setApp] = useState<AppId>(initialApp)

  const pick = (next: AppId) => {
    setApp(next)
    window.history.replaceState(null, '', `/?app=${next}`)
  }

  return (
    <MotionConfig reducedMotion="user">
      <div className="relative min-h-dvh" style={{ background: c.bg }}>
        <Backdrop />
        <div className="sticky top-0 z-20 px-4 pt-3">
          <LayoutGroup id="app-switch">
            <nav className="mx-auto flex max-w-md gap-1 rounded-2xl p-1" style={glass.card} aria-label="Apps">
              {APPS.map((a) => (
                <button
                  key={a.id}
                  onClick={() => pick(a.id)}
                  aria-current={app === a.id}
                  className="relative min-h-11 flex-1 rounded-xl text-sm font-semibold transition-colors"
                  style={{ color: app === a.id ? '#fff' : c.muted }}
                >
                  {app === a.id && (
                    <motion.span
                      layoutId="app-pill"
                      className="absolute inset-0 rounded-xl"
                      transition={{ type: 'spring', stiffness: 420, damping: 34 }}
                      style={{
                        background: `linear-gradient(180deg, #1c4668 0%, ${c.accent} 100%)`,
                        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), inset 0 -2px 0 rgba(0,0,0,0.24), 0 8px 16px -4px rgba(18,45,69,0.36)',
                      }}
                    />
                  )}
                  <span className="relative">{a.label}</span>
                </button>
              ))}
            </nav>
          </LayoutGroup>
        </div>
        <div className="relative z-10">
          {app === 'bounty' ? <BountyApp /> : app === 'escrow' ? <EscrowApp /> : <CrowdfundApp />}
        </div>
      </div>
    </MotionConfig>
  )
}
