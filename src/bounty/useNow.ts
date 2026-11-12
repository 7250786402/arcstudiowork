import { useEffect, useState } from 'react'

/** Current unix time in seconds, refreshed every 30 seconds. */
export function useNow() {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))
  useEffect(() => {
    const t = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 30000)
    return () => clearInterval(t)
  }, [])
  return now
}
