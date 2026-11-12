import { useAccount, useReadContract } from 'wagmi'
import { erc20Abi } from 'viem'
import { CHAIN_ID, USDC_ADDRESS, ZERO, short, usd } from '@/escrowTypes'
import { c, glass } from '@/escrow/theme'
import { AddressAvatar } from './AddressAvatar'

/** Desktop top-bar chip: who is connected, their USDC balance and the network. */
export function WalletChip({ compact = false }: { compact?: boolean }) {
  const { address, isConnected } = useAccount()
  const { data: balance } = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address ?? ZERO],
    chainId: CHAIN_ID,
    query: { enabled: !!address, refetchInterval: 20000 },
  })
  if (!isConnected || !address) return null
  if (compact) {
    return (
      <div className="mx-auto mt-2 flex w-fit items-center gap-2 rounded-full py-1 pl-1.5 pr-3.5 lg:hidden" style={glass.card}>
        <AddressAvatar address={address} size={20} />
        <span className="text-xs font-semibold tabular-nums" style={{ color: c.ink }}>{balance === undefined ? '--' : usd(balance)} USDC</span>
        <span className="text-[11px]" style={{ color: c.muted }}>Arc Testnet</span>
      </div>
    )
  }
  return (
    <div className="ml-auto hidden items-center gap-2.5 rounded-2xl py-1.5 pl-2 pr-3.5 lg:flex" style={glass.card}>
      <AddressAvatar address={address} size={28} />
      <div className="leading-tight">
        <p className="text-xs font-semibold tabular-nums" style={{ color: c.ink }}>{short(address)}</p>
        <p className="text-[11px] tabular-nums" style={{ color: c.muted }}>{balance === undefined ? '--' : usd(balance)} USDC on Arc Testnet</p>
      </div>
    </div>
  )
}
