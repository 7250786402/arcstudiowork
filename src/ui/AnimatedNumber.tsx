import { useEffect, useRef, useState } from 'react'
import { useReducedMotion } from 'framer-motion'

/**
 * Shows a number that counts to its value when the value changes. Non-numeric text is shown as is.
 * The final frame is always the exact text that was passed in.
 */
export function AnimatedNumber({ value }: { value: string }) {
  const reduce = useReducedMotion()
  const match = /^(\d+)(?:\.(\d+))?$/.exec(value)
  const target = match ? Number(value) : null
  const decimals = match?.[2]?.length ?? 0
  const [shown, setShown] = useState<number | null>(target === null ? null : 0)
  const current = useRef(0)

  useEffect(() => {
    if (target === null || reduce) return
    const from = current.current
    const start = performance.now()
    let raf = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / 700)
      const eased = 1 - Math.pow(1 - t, 3)
      current.current = from + (target - from) * eased
      setShown(current.current)
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, reduce])

  if (target === null || reduce || shown === null) return <>{value}</>
  return <>{Math.abs(shown - target) < 0.005 ? value : shown.toFixed(decimals)}</>
}
