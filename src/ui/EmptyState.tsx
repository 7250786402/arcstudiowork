import type { ReactNode } from 'react'
import { c, display, glass } from '@/escrow/theme'

export type EmptyKind = 'bounty' | 'escrow' | 'crowdfund' | 'wallet'

const STROKE = '#acc6e9'

function Art({ kind }: { kind: EmptyKind }) {
  return (
    <svg viewBox="0 0 160 120" className="mx-auto h-28 w-40" fill="none" aria-hidden>
      <defs>
        <linearGradient id="es-g" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#acc6e9" stopOpacity="0.5" />
          <stop offset="1" stopColor="#acc6e9" stopOpacity="0.06" />
        </linearGradient>
        <radialGradient id="es-glow" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="#acc6e9" stopOpacity="0.28" />
          <stop offset="1" stopColor="#acc6e9" stopOpacity="0" />
        </radialGradient>
      </defs>
      <ellipse cx="80" cy="62" rx="72" ry="52" fill="url(#es-glow)" />
      {kind === 'bounty' && (
        <>
          <rect x="44" y="18" width="62" height="82" rx="10" fill="url(#es-g)" stroke={STROKE} strokeOpacity="0.7" />
          <rect x="56" y="32" width="38" height="5" rx="2.5" fill={STROKE} fillOpacity="0.6" />
          <rect x="56" y="45" width="30" height="5" rx="2.5" fill={STROKE} fillOpacity="0.35" />
          <rect x="56" y="58" width="34" height="5" rx="2.5" fill={STROKE} fillOpacity="0.35" />
          <circle cx="108" cy="82" r="20" fill="#0f2a43" stroke={STROKE} strokeOpacity="0.8" />
          <text x="108" y="90" textAnchor="middle" fontSize="22" fontWeight="700" fill="#e8f1fb" fontFamily="Space Grotesk, sans-serif">$</text>
        </>
      )}
      {kind === 'escrow' && (
        <>
          <rect x="38" y="24" width="84" height="74" rx="14" fill="url(#es-g)" stroke={STROKE} strokeOpacity="0.7" />
          <circle cx="80" cy="56" r="17" fill="#0f2a43" stroke={STROKE} strokeOpacity="0.8" />
          <path d="M80 45v11l7 5" stroke="#e8f1fb" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
          <rect x="62" y="82" width="36" height="6" rx="3" fill={STROKE} fillOpacity="0.4" />
        </>
      )}
      {kind === 'crowdfund' && (
        <>
          <circle cx="80" cy="60" r="38" stroke={STROKE} strokeOpacity="0.25" strokeWidth="10" />
          <path d="M80 22a38 38 0 0 1 33 19" stroke={STROKE} strokeWidth="10" strokeLinecap="round" />
          <circle cx="80" cy="60" r="20" fill="url(#es-g)" stroke={STROKE} strokeOpacity="0.6" />
          <path d="M80 70V52m-8 8 8-8 8 8" stroke="#e8f1fb" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {kind === 'wallet' && (
        <>
          <rect x="34" y="34" width="92" height="62" rx="14" fill="url(#es-g)" stroke={STROKE} strokeOpacity="0.7" />
          <path d="M34 50h74a18 18 0 0 1 18 18v0" stroke={STROKE} strokeOpacity="0.5" />
          <circle cx="104" cy="72" r="6" fill="#0f2a43" stroke={STROKE} strokeOpacity="0.9" />
        </>
      )}
    </svg>
  )
}

/** Friendly empty state: a small illustration, one line of what is missing, and one next step. */
export function EmptyState({ kind, title, body, action }: { kind: EmptyKind; title: string; body: string; action?: ReactNode }) {
  return (
    <div className="rounded-3xl px-6 py-9 text-center" style={glass.card}>
      <Art kind={kind} />
      <p className="mt-3 text-base font-semibold text-balance" style={{ ...display, color: c.ink }}>{title}</p>
      <p className="mx-auto mt-1 max-w-xs text-sm text-pretty" style={{ color: c.muted }}>{body}</p>
      {action && <div className="mt-5 flex justify-center">{action}</div>}
    </div>
  )
}
