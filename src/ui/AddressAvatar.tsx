import { short } from '@/escrowTypes'

/** A stable colour per address, so the same person looks the same everywhere. */
export function AddressAvatar({ address, size = 18 }: { address: string; size?: number }) {
  const a = Number.parseInt(address.slice(2, 10), 16) % 360
  const b = (a + 50 + (Number.parseInt(address.slice(10, 12), 16) % 90)) % 360
  return (
    <span
      aria-hidden
      className="inline-block shrink-0 rounded-full"
      style={{
        width: size,
        height: size,
        background: `linear-gradient(135deg, hsl(${a} 72% 64%), hsl(${b} 66% 44%))`,
        boxShadow: 'inset 0 1px 1px rgba(255,255,255,0.45), 0 0 0 1px rgba(255,255,255,0.14)',
      }}
    />
  )
}

/** Avatar plus shortened address, with an optional "you" tag. */
export function AddressTag({ address, you = false, size = 18 }: { address: string; you?: boolean; size?: number }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <AddressAvatar address={address} size={size} />
      <span className="tabular-nums">{short(address)}</span>
      {you && (
        <span className="rounded-md px-1.5 py-px text-[10px] font-semibold uppercase tracking-wide" style={{ background: 'rgba(172,198,233,0.16)', color: '#acc6e9' }}>
          you
        </span>
      )}
    </span>
  )
}
