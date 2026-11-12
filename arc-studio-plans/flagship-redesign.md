## Implementation Plan: Flagship Dark Redesign (Bounty Board, Escrow, Crowdfund)

### Summary
Give all three apps a premium, dark immersive look: deep navy canvas, glow, a 3D signature visual per app driven by real data, and a desktop two-panel layout. All wallet flows stay as they are; only look and motion change.

### Architecture
- Blockchain: Arc Testnet, no change. The three contracts stay as deployed; no new deploy or review.
- Contract: no change.
- Frontend:
  - Arc Dark tokens (deep navy #0d1b2f, pale-blue CTA, glass-on-dark surfaces).
  - No new dependencies. CSS 3D, SVG and framer-motion only, because adding a package earlier caused a duplicate-React problem.
  - Visuals use only real data. With no data, a visual stays still.
  - Motion is tied to real state and respects prefers-reduced-motion.
- Wallet: ConnectKit stays, in dark mode.

### Files to Create/Modify
Foundation
1. src/escrow/theme.ts: dark tokens (ink, muted, accent, onAccent, success, danger), glass-on-dark surfaces, glow shadows. Keep export names so existing colours update automatically.
2. src/index.css: dark body, scrollbar, fonts. Replace the brittle navy-button CSS selector with the shared Button component.
3. src/main.tsx: ConnectKit mode dark. Keep the installShareSync() call.
4. src/ui/Button.tsx: shared button (primary, success, danger, ghost) with pressed, disabled and loading states.
5. src/ui/Skeleton.tsx, src/ui/EmptyState.tsx (SVG illustrations), src/ui/CountUp.tsx (smooth number on real value change), src/ui/Reveal.tsx (staggered card entrance).
6. src/ui/Backdrop.tsx: dark aurora with soft glow and a faint grid. No more than one large blob.
7. src/ui/AppShell.tsx: responsive layout. Desktop (1024px+): sticky summary panel on the left, content on the right. Phone: one column with the hero on top.
8. src/App.tsx: AppShell and the sliding app switch. Keep the ?app= and ?deal= logic.

Signature visuals (real data)
9. src/ui/Coin3D.tsx: upgraded shared coin.
10. src/ui/BountyPoolVisual.tsx: 3D coin stack. Height follows the real open reward pool, coin count follows open bounties; a new bounty drops a coin in.
11. src/ui/VaultVisual.tsx: 3D vault. Glow ring follows the real locked amount; unlock animation when a deal is Released.
12. src/ui/GoalRing.tsx: progress ring from real raised/goal. Large in the Crowdfund hero, small on each campaign card.
13. Replace src/ui/HeroCard.tsx with SummaryPanel: visual, large count-up number, stats.

Pages
14. Bounty Board: src/bounty/BountyApp.tsx, BountyCard.tsx, PostBountyForm.tsx, BountyActivity.tsx.
15. Escrow: src/escrow/EscrowApp.tsx, DealCard.tsx, DealActions.tsx, NewDealForm.tsx, DealTimeline.tsx (vertical rail with glowing nodes), Guide.tsx.
16. Crowdfund: src/crowdfund/CrowdfundApp.tsx, CampaignCard.tsx, StartCampaignForm.tsx, CampaignActivity.tsx.
17. src/lib/ActivityList.tsx: dark restyle.
18. README.md and AGENTS.md: design notes.

### Build Sequence
1. Foundation: theme tokens, index.css, Button, Backdrop, AppShell, App switch. Replace the ~16 `color: '#fff'` on accent surfaces with c.onAccent (white text would vanish on a light-blue button). Run checks. STOP for the user's screenshot to confirm direction.
2. Shared pieces: Skeleton, EmptyState, CountUp, Reveal, SummaryPanel, Coin3D upgrade.
3. Bounty Board in full: pool visual, cards, form, empty and loading states. Run checks. STOP for a screenshot.
4. Escrow in full: vault visual, deal cards, actions, timeline.
5. Crowdfund in full: goal ring, campaign cards, form.
6. Motion pass: entrance, count-up, state transitions. Reduced-motion check.
7. Final pass: contrast, 44px tap targets, phone and desktop widths, bun run check, no console errors in preview.
8. Deploy only when the user asks.

### Risks
- Wallet flows must not break: do not touch hooks or transaction logic (useTxFlow, contract calls); change markup and styles only; typecheck and render-check after each app.
- Dark-mode contrast: handled by the c.onAccent codemod up front.
- Performance: few blur layers; 3D tilt off on touch devices.
- The builder cannot see the screen: screenshots from the user after steps 1 and 3.

### Done When
- [ ] All three apps share one dark design language.
- [ ] Desktop shows two panels; phone shows a clean single column.
- [ ] Each app's signature visual is driven by real data and is still when there is none.
- [ ] Skeletons while loading, illustrated empty states.
- [ ] Bounty post, submit, award; Escrow fund, accept, release; Crowdfund pledge, refund still work as before.
- [ ] bun run check is clean and the preview console shows no errors.
- [ ] Animations stop under reduced-motion.

## Ready to build?
