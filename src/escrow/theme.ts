import type { CSSProperties } from 'react'

/** Arc Dark. One deep-navy canvas, a pale-blue accent, glass-on-dark surfaces. */
export const SPECTRAL = 'linear-gradient(90deg,#5fbeff,#af8ff4,#f05c6b,#ffcd83,#7ef1b3)'

export const c = {
  ink: '#f4f7fb',
  muted: '#b4c2d4',
  subtle: '#8497ad',
  /** Primary action colour (pale blue). Text placed on it must use onAccent. */
  accent: '#acc6e9',
  onAccent: '#0d1b2f',
  success: '#8dd89f',
  onSuccess: '#0d2a18',
  danger: '#f0808c',
  onDanger: '#2a0b10',
  warn: '#e6b45a',
  bg: 'linear-gradient(180deg,#0b1627 0%,#0d1b2f 58%,#122d45 100%)',
}

export const glass: Record<'card' | 'inner' | 'hero', CSSProperties> = {
  card: {
    background: 'linear-gradient(160deg, rgba(255,255,255,0.095) 0%, rgba(255,255,255,0.04) 100%)',
    backdropFilter: 'blur(22px) saturate(150%)',
    WebkitBackdropFilter: 'blur(22px) saturate(150%)',
    border: '1px solid rgba(255,255,255,0.10)',
    boxShadow:
      '0 1px 0 rgba(255,255,255,0.12) inset, 0 -1px 0 rgba(0,0,0,0.25) inset, 0 2px 4px rgba(0,0,0,0.28), 0 22px 44px -14px rgba(0,0,0,0.55)',
  },
  /** Fields and chips sit slightly pressed into the card. */
  inner: {
    background: 'rgba(255,255,255,0.055)',
    border: '1px solid rgba(255,255,255,0.09)',
    boxShadow: 'inset 0 2px 6px rgba(0,0,0,0.28)',
  },
  hero: {
    background: 'linear-gradient(150deg, rgba(172,198,233,0.16) 0%, rgba(255,255,255,0.05) 46%, rgba(255,255,255,0.03) 100%)',
    backdropFilter: 'blur(26px) saturate(160%)',
    WebkitBackdropFilter: 'blur(26px) saturate(160%)',
    border: '1px solid rgba(172,198,233,0.22)',
    boxShadow:
      '0 1px 0 rgba(255,255,255,0.18) inset, 0 -1px 0 rgba(0,0,0,0.3) inset, 0 4px 8px rgba(0,0,0,0.3), 0 34px 70px -22px rgba(0,0,0,0.7), 0 0 64px -24px rgba(172,198,233,0.3)',
  },
}

export const display: CSSProperties = { fontFamily: "'Space Grotesk', sans-serif", letterSpacing: '-0.02em' }
