import { useCallback, useEffect, useRef, useState } from 'react'
import { toast } from 'sonner'
import { useAccount, useSwitchChain, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { buildTxExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID, parseErr } from '@/escrowTypes'
import { celebrate } from '@/lib/celebrate'

type WriteAsync = ReturnType<typeof useWriteContract>['writeContractAsync']

const REVERTED = 'The transaction was reverted onchain, so nothing changed. Refresh and check the status before trying again.'

/** One transaction at a time: switch chain if needed, sign, then wait for the real receipt and report it. */
export function useTxFlow(onConfirmed?: () => void, options?: { celebrate?: boolean }) {
  const celebrateOn = options?.celebrate !== false
  const { chainId } = useAccount()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync, isPending } = useWriteContract()
  const [hash, setHash] = useState<`0x${string}` | undefined>()
  const [error, setError] = useState('')
  const { data: receipt, isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash })
  const doneFor = useRef<string | undefined>(undefined)

  const confirmed = isSuccess && receipt?.status === 'success'
  const reverted = isSuccess && receipt?.status === 'reverted'

  useEffect(() => {
    if (hash) toast.loading('Transaction sent. Waiting for confirmation.', { id: hash })
  }, [hash])

  useEffect(() => {
    if (!hash || doneFor.current === hash) return
    if (confirmed) {
      doneFor.current = hash
      toast.success('Confirmed on Arc Testnet', {
        id: hash,
        action: { label: 'View', onClick: () => window.open(buildTxExplorerUrl(CHAIN_ID, hash), '_blank', 'noopener,noreferrer') },
      })
      if (celebrateOn) celebrate()
      onConfirmed?.()
    } else if (reverted) {
      doneFor.current = hash
      toast.error(REVERTED, { id: hash })
    }
  }, [confirmed, reverted, hash, onConfirmed, celebrateOn])

  const run = useCallback(
    async (send: (write: WriteAsync) => Promise<`0x${string}`>) => {
      setError('')
      try {
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID })
        setHash(await send(writeContractAsync))
      } catch (e) {
        setError(parseErr(e))
      }
    },
    [chainId, switchChainAsync, writeContractAsync],
  )

  return {
    run,
    hash,
    error: error || (reverted ? REVERTED : ''),
    pending: isPending,
    confirming,
    busy: isPending || confirming,
    success: confirmed && !!hash,
    clearError: () => setError(''),
  }
}
