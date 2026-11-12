import type { ReactNode } from 'react'
import { Info } from 'lucide-react'
import { c, glass } from '@/escrow/theme'

/**
 * Sits above a form's main button. Says in plain words what the next click will do,
 * and (when the button is disabled) exactly what is still missing.
 */
export function ActionNote({ summary, missing = [] }: { summary: ReactNode; missing?: string[] }) {
  return (
    <div className="space-y-2" aria-live="polite">
      <div className="flex gap-2.5 rounded-2xl p-3 text-xs text-pretty" style={{ ...glass.inner, color: c.muted }}>
        <Info className="mt-0.5 size-4 shrink-0" style={{ color: c.accent }} aria-hidden />
        <p>
          <span className="font-semibold" style={{ color: c.ink }}>You are about to: </span>
          {summary}
        </p>
      </div>
      {missing.length > 0 && (
        <p className="text-xs font-medium text-pretty" style={{ color: c.warn }}>Still needed: {missing.join(', ')}.</p>
      )}
    </div>
  )
}

/** Bold-ish value used inside an ActionNote summary. */
export function Strong({ children }: { children: ReactNode }) {
  return <span className="font-semibold" style={{ color: c.ink }}>{children}</span>
}
