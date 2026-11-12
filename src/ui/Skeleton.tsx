import type { CSSProperties } from 'react'

/** Shimmering placeholder for content that is still loading from the chain. */
export function Skeleton({ className = '', style }: { className?: string; style?: CSSProperties }) {
  return <div aria-hidden className={`shimmer rounded-xl ${className}`} style={style} />
}
