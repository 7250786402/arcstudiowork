import { useEffect, useRef, useState } from 'react'
import { useReducedMotion } from 'framer-motion'

/**
 * Shows a USDC amount (raw 6-decimal units) and eases toward it whenever the real value changes.
 * Nothing animates unless the value actually arrived from the chain or changed.
 * Under reduced motion it simply shows the value.
 */
export function CountUp({ raw, format, fallback = '--' }: { raw: bigint | null; format: (raw: bigint) => string; fallback?: string }) {
  const reduce = useReducedMotion()
  const target = raw === null ? null : Number(raw)
  const [shown, setShown] = useState<number | null>(null)
  const current = useRef(0)

  useEffect(() => {
    if (target === null || reduce) return
    let raf = 0
    const tick = () => {
      current.current += (target - current.current) * 0.16
      if (Math.abs(target - current.current) < 1) current.current = target
      setShown(current.current)
      if (current.current !== target) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, reduce])

  if (raw === null) return <>{fallback}</>
  if (reduce) return <>{format(raw)}</>
  if (shown === null) return <>{format(0n)}</>
  return <>{format(shown === Number(raw) ? raw : BigInt(Math.round(shown)))}</>
}
