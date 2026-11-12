import { useMemo, useSyncExternalStore } from 'react'

export type PendingApp = 'bounty' | 'escrow' | 'crowdfund'
export interface PendingItem {
  hash: `0x${string}`
  app: PendingApp
  label: string
}

let items: PendingItem[] = []
const listeners = new Set<() => void>()
const emit = () => listeners.forEach((l) => l())

/** Remember a transaction that was sent but is not confirmed yet. Adding the same hash twice does nothing. */
export function addPending(item: PendingItem) {
  if (items.some((i) => i.hash === item.hash)) return
  items = [...items, item]
  emit()
}

export function removePending(hash: string) {
  items = items.filter((i) => i.hash !== hash)
  emit()
}

const subscribe = (l: () => void) => {
  listeners.add(l)
  return () => listeners.delete(l)
}

export function usePending(app: PendingApp): PendingItem[] {
  const all = useSyncExternalStore(subscribe, () => items)
  return useMemo(() => all.filter((i) => i.app === app), [all, app])
}
