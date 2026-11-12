import { ESCROW_ABI } from '@/escrowAbi'
import { ESCROW_ADDRESS } from '@/escrowTypes'
import { useContractEvents } from '@/lib/useContractEvents'
import type { ChainEvent } from '@/lib/useContractEvents'

export type DealEvent = ChainEvent

/** Escrow events for the deal timeline. */
export function useDealEvents() {
  return useContractEvents({ key: 'escrow', address: ESCROW_ADDRESS, abi: ESCROW_ABI })
}
