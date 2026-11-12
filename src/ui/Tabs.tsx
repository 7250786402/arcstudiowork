import { LayoutGroup, motion } from 'framer-motion'
import { c, glass } from '@/escrow/theme'

interface Tab<T extends string> {
  id: T
  label: string
  /** Real count of things that need the user (shown as a small red badge). */
  badge?: number
}

/** Segmented control with a pill that slides to the selected tab. */
export function Tabs<T extends string>({ group, tabs, value, onChange }: { group: string; tabs: readonly Tab<T>[]; value: T; onChange: (id: T) => void }) {
  return (
    <LayoutGroup id={group}>
      <nav className="flex gap-1 rounded-2xl p-1" style={glass.card} aria-label="Sections">
        {tabs.map((t) => {
          const active = t.id === value
          return (
            <button key={t.id} onClick={() => onChange(t.id)} aria-current={active} className="relative min-h-11 flex-1 rounded-xl text-sm font-semibold">
              {active && (
                <motion.span
                  layoutId="tab-pill"
                  className="absolute inset-0 rounded-xl"
                  style={{ background: 'linear-gradient(180deg,#cfe0f4 0%,#acc6e9 100%)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.6), 0 8px 18px -6px rgba(172,198,233,0.5)' }}
                  transition={{ type: 'spring', stiffness: 420, damping: 34 }}
                />
              )}
              <span className="relative z-10 transition-colors" style={{ color: active ? c.onAccent : c.muted }}>{t.label}</span>
              {t.badge !== undefined && t.badge > 0 && (
                <span className="absolute -right-0.5 -top-1 z-10 flex size-4 items-center justify-center rounded-full text-[10px] font-bold" style={{ background: c.danger, color: c.onDanger }}>
                  {t.badge}
                </span>
              )}
            </button>
          )
        })}
      </nav>
    </LayoutGroup>
  )
}
