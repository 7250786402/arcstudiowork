import type { ReactNode } from 'react'
import { motion } from 'framer-motion'

/** Fades and lifts a block in. Pass the list index to stagger a run of cards. */
export function Reveal({ children, index = 0, className, fresh = false }: { children: ReactNode; index?: number; className?: string; fresh?: boolean }) {
  return (
    <motion.div
      className={`${className ?? ''}${fresh ? ' fresh-glow' : ''}`}
      initial={{ opacity: 0, y: fresh ? -28 : 12, scale: fresh ? 0.97 : 1 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.32, delay: Math.min(index, 8) * 0.05, ease: [0.25, 0.1, 0.25, 1] }}
    >
      {children}
    </motion.div>
  )
}
