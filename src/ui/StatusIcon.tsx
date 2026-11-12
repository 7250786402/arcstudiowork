import { AlertTriangle, Check, Circle, Clock, X } from 'lucide-react'

export type StatusKind = 'live' | 'done' | 'closed' | 'warn' | 'alert'

/** Small icon that backs up a status chip, so the meaning never depends on colour alone. */
export function StatusIcon({ kind }: { kind: StatusKind }) {
  const cls = 'size-3 shrink-0'
  if (kind === 'done') return <Check aria-hidden className={cls} strokeWidth={3} />
  if (kind === 'closed') return <X aria-hidden className={cls} strokeWidth={3} />
  if (kind === 'warn') return <Clock aria-hidden className={cls} strokeWidth={2.5} />
  if (kind === 'alert') return <AlertTriangle aria-hidden className={cls} strokeWidth={2.5} />
  return <Circle aria-hidden className="size-2 shrink-0" fill="currentColor" strokeWidth={0} />
}
