import type { ReactNode } from 'react'

/**
 * Responsive page frame shared by every app.
 * Desktop (1024px and up): a sticky summary panel on the left, content on the right.
 * Phone: one column with the summary on top.
 */
export function AppShell({ side, children }: { side: ReactNode; children: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-md px-4 pb-16 pt-5 lg:grid lg:max-w-6xl lg:grid-cols-[400px_minmax(0,1fr)] lg:items-start lg:gap-8 lg:px-8">
      <aside className="space-y-4 lg:sticky lg:top-24">{side}</aside>
      <main className="mt-4 space-y-4 lg:mt-0">{children}</main>
    </div>
  )
}
