import { useEffect, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'

/** Seconds since the newest chain data arrived, or null before any has. Checked every 5 seconds. */
export function useLastSync(): number | null {
  const qc = useQueryClient()
  const [ago, setAgo] = useState<number | null>(null)
  useEffect(() => {
    const tick = () => {
      const latest = qc.getQueryCache().getAll().reduce((max, q) => Math.max(max, q.state.dataUpdatedAt), 0)
      setAgo(latest === 0 ? null : Math.max(0, Math.round((Date.now() - latest) / 1000)))
    }
    tick()
    const id = window.setInterval(tick, 5000)
    return () => window.clearInterval(id)
  }, [qc])
  return ago
}

export function formatAgo(seconds: number): string {
  if (seconds < 5) return 'just now'
  if (seconds < 60) return `${seconds}s ago`
  return `${Math.floor(seconds / 60)}m ago`
}
