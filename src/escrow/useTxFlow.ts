import { useCallback, useEffect, useRef, useState } from 'react'
import { useAccount, useSwitchChain, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { CHAIN_ID, parseErr } from '@/escrowTypes'

type WriteAsync = ReturnType<typeof useWriteContract>['writeContractAsync']

/** One transaction at a time: switch chain if needed, sign, then wait for the real receipt. */
export function useTxFlow(onConfirmed?: () => void) {
  const { chainId } = useAccount()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync, isPending } = useWriteContract()
  const [hash, setHash] = useState<`0x${string}` | undefined>()
  const [error, setError] = useState('')
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash })
  const doneFor = useRef<string | undefined>(undefined)

  useEffect(() => {
    if (isSuccess && hash && doneFor.current !== hash) {
      doneFor.current = hash
      onConfirmed?.()
    }
  }, [isSuccess, hash, onConfirmed])

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
    error,
    pending: isPending,
    confirming,
    busy: isPending || confirming,
    success: isSuccess && !!hash,
    clearError: () => setError(''),
  }
}
