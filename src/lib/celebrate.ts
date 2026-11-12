import { useSyncExternalStore } from 'react'

let count = 0
const listeners = new Set<() => void>()

/** Ask the success layer to play its short confirmation animation. */
export function celebrate() {
  count += 1
  listeners.forEach((l) => l())
}

const subscribe = (l: () => void) => {
  listeners.add(l)
  return () => listeners.delete(l)
}

/** Number of confirmations so far; changes each time celebrate() is called. */
export function useCelebrations(): number {
  return useSyncExternalStore(subscribe, () => count)
}
