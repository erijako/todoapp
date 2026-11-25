# Design audit (Impeccable, native iOS), 2026-11-25

Method: `.claude/skills/impeccable` → `audit.native.md` + `ios.md`, **from source only** (no Simulator or
device screenshots in this environment; verify on TestFlight). Mode: Operate (app UI).

## Health score

| # | Dimension | Score | Key finding |
|---|---|---|---|
| 1 | Accessibility | 2 | Tap targets under 44 pt; "open details" only via `onTapGesture` (VoiceOver can't reach it); fixed button heights clip at large Dynamic Type; Reduce Motion ignored |
| 2 | Performance | 4 | System `List` + `@Query`; nothing heavy on launch |
| 3 | Appearance & theming | 3 | Theme tokens with light/dark everywhere except a few raw colors in onboarding |
| 4 | Platform conformance | 3 | System list, segmented picker, sheets, swipe actions, context menus, SF Symbols; two custom tap areas |
| 5 | Adaptivity | 3 | iPhone + portrait by decision; keyboard handled via `safeAreaInset` |
| **Total** | | **15/20** | **Good** |

**Platform verdict: pass.** Reads as a native app, not a web port.

## Findings

**P1**
1. `TaskRow` check button is 26×26 pt (`ContentView.swift`, `CheckCircle`): below 44 pt. Give it a 44 pt
   frame + `contentShape`.
2. Opening a task's details uses `.onTapGesture` on the row text (`ContentView.swift:585`) and on the
   whole Up Next card (`:168`). No button trait, so VoiceOver/Switch Control can't open details, and on
   the card it wraps the Focus button (known STATUS risk). Use a real `Button` for the text area.
3. Text buttons use fixed `.frame(height: 44/48/58)` (Focus, Paywall, Onboarding): at accessibility
   Dynamic Type sizes the label clips. Use `minHeight`.

**P2**
4. Reduce Motion is never read (44 animation sites: springs, scale transitions, iOS 18 zoom into focus).
   Add `@Environment(\.accessibilityReduceMotion)` and fall back to opacity/no animation.
5. Raw colors outside `Theme` in onboarding (`Color(hex: 0x3F7F6B)`, `.white`, a `0x2B3050` gradient):
   break the "colors only from Theme" rule; check dark mode contrast.

**P3**
6. Decorative symbols with fixed point sizes (paywall/focus/onboarding hero icons, avatar initials):
   fine as decoration; consider `.imageScale`/`relativeTo:` so they scale with text.

## Next steps
- `polish` / `harden` for P1–P2 (small, mechanical changes).
- Verify on device: largest Dynamic Type size, Dark Mode, VoiceOver pass on list + Up Next + sharing.
