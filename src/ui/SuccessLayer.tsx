import { useEffect, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useCelebrations } from '@/lib/celebrate'
import { c, display } from '@/escrow/theme'

/**
 * A brief confirmation mark in the middle of the screen when a real transaction is confirmed:
 * a ring that opens outward and a check that draws itself. It does not block the page.
 */
export function SuccessLayer() {
  const n = useCelebrations()
  const [dismissed, setDismissed] = useState(0)
  const visible = n > 0 && dismissed !== n ? n : 0

  useEffect(() => {
    if (n === 0) return
    const id = window.setTimeout(() => setDismissed(n), 1700)
    return () => window.clearTimeout(id)
  }, [n])

  return (
    <AnimatePresence>
      {visible > 0 && (
        <motion.div
          key={visible}
          aria-hidden
          className="pointer-events-none fixed inset-0 z-50 flex flex-col items-center justify-center gap-3"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
        >
          <motion.div
            className="relative flex size-24 items-center justify-center rounded-full"
            style={{ background: 'rgba(13,27,47,0.82)', border: '1px solid rgba(141,216,159,0.5)', boxShadow: '0 0 60px rgba(141,216,159,0.35), inset 0 1px 0 rgba(255,255,255,0.15)', backdropFilter: 'blur(14px)' }}
            initial={{ scale: 0.6, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', stiffness: 260, damping: 18 }}
          >
            <motion.span
              className="absolute inset-0 rounded-full"
              style={{ border: '2px solid rgba(141,216,159,0.6)' }}
              initial={{ scale: 1, opacity: 0.8 }}
              animate={{ scale: 1.9, opacity: 0 }}
              transition={{ duration: 0.9, ease: 'easeOut' }}
            />
            <svg viewBox="0 0 52 52" className="size-12" fill="none">
              <motion.path
                d="M14 27 L23 36 L39 17"
                stroke={c.success}
                strokeWidth="5"
                strokeLinecap="round"
                strokeLinejoin="round"
                initial={{ pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: 0.45, delay: 0.15, ease: 'easeOut' }}
              />
            </svg>
          </motion.div>
          <motion.p
            className="text-sm font-semibold"
            style={{ ...display, color: c.ink, textShadow: '0 1px 8px rgba(0,0,0,0.6)' }}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.35 }}
          >
            Confirmed on Arc Testnet
          </motion.p>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
