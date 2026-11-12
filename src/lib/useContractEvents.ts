import { useQuery } from '@tanstack/react-query'
import { decodeEventLog } from 'viem'
import type { Abi } from 'viem'
import { usePublicClient } from 'wagmi'
import { buildAddressExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID } from '@/escrowTypes'
import type { Addr } from '@/escrowTypes'

export interface ChainEvent {
  eventName: string
  args: Record<string, unknown>
  blockNumber: bigint
  transactionHash: `0x${string}`
  logIndex: number
  /** Unix seconds. Missing when the events came from the RPC fallback. */
  timestamp?: number
}

interface ExplorerLog {
  block_number: number
  block_timestamp?: string
  transaction_hash: `0x${string}`
  index: number
  topics: (string | null)[]
  data: `0x${string}`
}

interface ExplorerPage {
  items?: ExplorerLog[]
  next_page_params?: Record<string, string | number> | null
}

const MAX_PAGES = 20
// The public RPC refuses eth_getLogs ranges above 5,000 blocks (measured on 11 Nov 2026), so keep the fallback under that.
const RPC_FALLBACK_BLOCKS = 4_900n

async function fromExplorer(address: Addr, abi: Abi): Promise<ChainEvent[]> {
  const origin = new URL(buildAddressExplorerUrl(CHAIN_ID, address)).origin
  const base = `${origin}/api/v2/addresses/${address}/logs`
  const out: ChainEvent[] = []
  let params: Record<string, string | number> | null = null
  for (let page = 0; page < MAX_PAGES; page++) {
    const qs = params ? `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}` : ''
    const res = await fetch(`${base}${qs}`)
    if (!res.ok) throw new Error(`Explorer returned ${res.status}`)
    const body = (await res.json()) as ExplorerPage
    for (const log of body.items ?? []) {
      try {
        const topics = log.topics.filter((t): t is string => typeof t === 'string') as [`0x${string}`, ...`0x${string}`[]]
        const decoded = decodeEventLog({ abi, data: log.data, topics })
        out.push({
          eventName: String(decoded.eventName),
          args: (decoded.args ?? {}) as unknown as Record<string, unknown>,
          blockNumber: BigInt(log.block_number),
          transactionHash: log.transaction_hash,
          logIndex: log.index,
          timestamp: log.block_timestamp ? Math.floor(Date.parse(log.block_timestamp) / 1000) : undefined,
        })
      } catch {
        // Not an event this app knows; skip it.
      }
    }
    params = body.next_page_params ?? null
    if (!params) break
  }
  return out
}

/**
 * All events of one contract, newest data included. Reads the chain explorer's log API (no block-range limit);
 * if that is unreachable, falls back to the most recent blocks from the RPC.
 */
export function useContractEvents({ key, address, abi }: { key: string; address: Addr; abi: Abi }) {
  const client = usePublicClient({ chainId: CHAIN_ID })
  return useQuery({
    queryKey: ['contract-events', key, address],
    enabled: !!client,
    refetchInterval: 30000,
    queryFn: async (): Promise<ChainEvent[]> => {
      try {
        return await fromExplorer(address, abi)
      } catch {
        if (!client) throw new Error('No public client')
        const head = await client.getBlockNumber()
        const logs = await client.getContractEvents({ abi, address, fromBlock: head - RPC_FALLBACK_BLOCKS, toBlock: head })
        return logs.map((l) => ({
          eventName: String(l.eventName),
          args: l.args as unknown as Record<string, unknown>,
          blockNumber: l.blockNumber,
          transactionHash: l.transactionHash,
          logIndex: l.logIndex,
        }))
      }
    },
  })
}

export const asBig = (v: unknown): bigint | undefined => (typeof v === 'bigint' ? v : undefined)
export const asStr = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined)
