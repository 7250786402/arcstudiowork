import type { CSSProperties } from 'react'

export const SPECTRAL = 'linear-gradient(90deg,#5fbeff,#af8ff4,#f05c6b,#ffcd83,#7ef1b3)'

export const c = {
  ink: '#0f1c2e',
  muted: '#5c6b7c',
  subtle: '#8a97a6',
  accent: '#122d45',
  success: '#1a8047',
  danger: '#c0392b',
  warn: '#b7791f',
  bg: 'linear-gradient(180deg,#f9f9fc 0%,#fffcf7 52%,#fbf7f2 100%)',
}

/** Layered shadows give cards real depth: a top highlight, a tight contact shadow and two soft ambient ones. */
const RAISED =
  '0 1px 0 rgba(255,255,255,0.95) inset, 0 -1px 0 rgba(18,45,69,0.04) inset, 0 2px 4px rgba(18,45,69,0.04), 0 14px 26px -8px rgba(18,45,69,0.10), 0 34px 52px -18px rgba(18,45,69,0.12)'

export const glass: Record<'card' | 'inner' | 'hero', CSSProperties> = {
  card: {
    background: 'rgba(255,255,255,0.68)',
    backdropFilter: 'blur(24px) saturate(180%)',
    WebkitBackdropFilter: 'blur(24px) saturate(180%)',
    border: '1px solid rgba(255,255,255,0.72)',
    boxShadow: RAISED,
  },
  /** Fields and chips sit slightly pressed into the card. */
  inner: {
    background: 'rgba(255,255,255,0.52)',
    border: '1px solid rgba(18,45,69,0.08)',
    boxShadow: 'inset 0 1px 2px rgba(18,45,69,0.06)',
  },
  hero: {
    background: 'linear-gradient(145deg, rgba(255,255,255,0.88) 0%, rgba(255,255,255,0.62) 100%)',
    backdropFilter: 'blur(28px) saturate(190%)',
    WebkitBackdropFilter: 'blur(28px) saturate(190%)',
    border: '1px solid rgba(255,255,255,0.85)',
    boxShadow:
      '0 1px 0 rgba(255,255,255,1) inset, 0 -1px 0 rgba(18,45,69,0.05) inset, 0 3px 6px rgba(18,45,69,0.05), 0 22px 38px -10px rgba(18,45,69,0.16), 0 50px 70px -26px rgba(18,45,69,0.18)',
  },
}

export const display: CSSProperties = { fontFamily: "'Space Grotesk', sans-serif", letterSpacing: '-0.02em' }
