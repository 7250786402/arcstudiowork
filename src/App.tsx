import { Suspense, lazy, useState } from 'react'
import { LayoutGroup, MotionConfig, motion } from 'framer-motion'
import { c, display, glass } from './escrow/theme'
import { Backdrop } from './ui/Backdrop'
import { Skeleton } from './ui/Skeleton'
import { WalletChip } from './ui/WalletChip'
import { SuccessLayer } from './ui/SuccessLayer'

const BountyApp = lazy(() => import('./bounty/BountyApp'))
const EscrowApp = lazy(() => import('./escrow/EscrowApp'))
const CrowdfundApp = lazy(() => import('./crowdfund/CrowdfundApp'))

function AppFallback() {
  return (
    <div className="mx-auto w-full max-w-md space-y-4 px-4 py-6 lg:max-w-6xl lg:px-8" aria-busy="true">
      <Skeleton className="h-8 w-48" />
      <Skeleton className="h-72 w-full rounded-3xl" />
      <Skeleton className="h-24 w-full rounded-3xl" />
    </div>
  )
}

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

/** Small coin mark used as the site badge. */
function Mark() {
  return (
    <span aria-hidden className="flex size-9 items-center justify-center rounded-full" style={{ background: 'conic-gradient(from 210deg, #5fbeff, #af8ff4, #f05c6b, #ffcd83, #7ef1b3, #5fbeff)', padding: 2 }}>
      <span className="flex size-full items-center justify-center rounded-full text-sm font-bold" style={{ ...display, background: 'radial-gradient(circle at 30% 25%, #2d6296, #0f2a43)', color: '#e8f1fb' }}>$</span>
    </span>
  )
}

export default function App() {
  const [app, setApp] = useState<AppId>(initialApp)

  const pick = (next: AppId) => {
    setApp(next)
    window.history.replaceState(null, '', `/?app=${next}`)
  }

  return (
    <MotionConfig reducedMotion="user">
      <div className="relative min-h-dvh">
        <Backdrop />
        <SuccessLayer />
        <div className="relative z-10">
          <div className="sticky top-0 z-30 px-4 pt-3">
            <div className="mx-auto flex max-w-md items-center gap-3 lg:max-w-6xl lg:px-4">
              <div className="hidden lg:block"><Mark /></div>
              <LayoutGroup id="app-switch">
                <nav className="flex flex-1 gap-1 rounded-2xl p-1 lg:max-w-md lg:flex-none" style={glass.card} aria-label="Apps">
                  {APPS.map((a) => (
                    <button key={a.id} onClick={() => pick(a.id)} aria-current={app === a.id}
                      className="relative min-h-11 flex-1 rounded-xl px-2 text-sm font-semibold transition-colors lg:px-5"
                      style={{ color: app === a.id ? c.onAccent : c.muted }}>
                      {app === a.id && (
                        <motion.span layoutId="app-pill" className="absolute inset-0 rounded-xl"
                          style={{ background: `linear-gradient(180deg, #cfe0f5 0%, ${c.accent} 100%)`, boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.6), 0 8px 20px -8px rgba(172,198,233,0.55)' }}
                          transition={{ type: 'spring', stiffness: 420, damping: 34 }} />
                      )}
                      <span className="relative z-10">{a.label}</span>
                    </button>
                  ))}
                </nav>
              </LayoutGroup>
              <WalletChip />
            </div>
            <WalletChip compact />
          </div>
          <Suspense fallback={<AppFallback />}>
            {app === 'bounty' ? <BountyApp /> : app === 'escrow' ? <EscrowApp /> : <CrowdfundApp />}
          </Suspense>
        </div>
      </div>
    </MotionConfig>
  )
}
