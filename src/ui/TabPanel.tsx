import type { ReactNode } from 'react'
import { motion } from 'framer-motion'

/** Fades and lifts its content in when a tab opens. Reduced motion is handled by the app-wide MotionConfig. */
export function TabPanel({ children }: { children: ReactNode }) {
  return (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.24, ease: [0.25, 0.1, 0.25, 1] }}>
      {children}
    </motion.div>
  )
}
