import type { ButtonHTMLAttributes, CSSProperties, ReactNode } from 'react'
import { Loader2 } from 'lucide-react'
import { c } from '@/escrow/theme'

export type ButtonVariant = 'primary' | 'success' | 'danger' | 'ghost'

const VARIANT: Record<ButtonVariant, CSSProperties> = {
  primary: {
    background: `linear-gradient(180deg, #cfe0f5 0%, ${c.accent} 100%)`,
    color: c.onAccent,
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.6), inset 0 -2px 0 rgba(13,27,47,0.22), 0 10px 24px -8px rgba(172,198,233,0.5)',
  },
  success: {
    background: `linear-gradient(180deg, #b6ecc4 0%, ${c.success} 100%)`,
    color: c.onSuccess,
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.55), inset 0 -2px 0 rgba(13,42,24,0.2), 0 10px 24px -8px rgba(141,216,159,0.45)',
  },
  danger: {
    background: 'rgba(240,128,140,0.12)',
    color: c.danger,
    border: '1px solid rgba(240,128,140,0.3)',
  },
  ghost: {
    background: 'rgba(255,255,255,0.07)',
    color: c.ink,
    border: '1px solid rgba(255,255,255,0.12)',
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08)',
  },
}

interface ButtonProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  variant?: ButtonVariant
  loading?: boolean
  block?: boolean
  size?: 'md' | 'sm'
  children: ReactNode
}

/** The one button for the whole site: pressed, hover, disabled and loading states included. */
export function Button({ variant = 'primary', loading = false, block = false, size = 'md', className = '', style, disabled, children, ...rest }: ButtonProps) {
  const sizing = size === 'md' ? 'min-h-11 rounded-2xl px-4 text-sm' : 'min-h-11 rounded-xl px-3 text-xs'
  return (
    <button
      type="button"
      {...rest}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={`btn inline-flex items-center justify-center gap-2 font-semibold ${sizing} ${block ? 'w-full' : ''} ${className}`}
      style={{ ...VARIANT[variant], ...style }}
    >
      {loading && <Loader2 className="size-4 animate-spin" aria-hidden />}
      {children}
    </button>
  )
}
