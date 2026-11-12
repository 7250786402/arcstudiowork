import { useEffect, useRef, useState } from 'react'

/**
 * Keys that appeared after the list first loaded (a new bounty, deal or campaign), kept for a few seconds
 * so the card can announce itself. Nothing is marked on the first load.
 */
export function useFreshKeys(keys: readonly string[], ready: boolean): ReadonlySet<string> {
  const known = useRef<Set<string> | null>(null)
  const [fresh, setFresh] = useState<ReadonlySet<string>>(new Set())
  const joined = keys.join('|')

  useEffect(() => {
    if (!ready) return
    const list = joined === '' ? [] : joined.split('|')
    if (known.current === null) {
      known.current = new Set(list)
      return
    }
    const seen = known.current
    const added = list.filter((k) => !seen.has(k))
    if (added.length === 0) return
    added.forEach((k) => seen.add(k))
    setFresh((prev) => new Set([...prev, ...added]))
    window.setTimeout(() => {
      setFresh((prev) => {
        const next = new Set(prev)
        added.forEach((k) => next.delete(k))
        return next
      })
    }, 2600)
  }, [joined, ready])

  return fresh
}
