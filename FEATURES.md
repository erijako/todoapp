# Feature List

> **Positioning:** A to-do app built for ADHD brains.
> **Pitch:** Out of sight, out of mind — so we put your next step where you look 100 times a day: your lock screen.

Platform: **iOS first** (native SwiftUI). Language: **English** by default, **Norwegian** later.

---

## Design principles

1. **One thing at a time.** Show the next step, not the whole mountain.
2. **Zero friction capture.** Get it out of your head in 2 seconds. Sort later (or never).
3. **No shame.** No red overdue piles, no broken-streak guilt. Unfinished tasks quietly roll over.
4. **Make time visible.** Fight time blindness with timers and countdowns you can see.
5. **Reward progress.** Satisfying check-offs, haptics and small wins — dopamine, not pressure.
6. **Never make medical claims.** "Built for ADHD brains", not "treats ADHD".

---

## ADHD pain points → features

| Pain point | Feature |
|---|---|
| Out of sight, out of mind | Lock screen widget showing **one** next task, check off from the lock screen |
| Overwhelm / task paralysis | "Just one thing" focus mode; hide everything except the current task |
| Can't get started | Break a task into tiny steps (manual, AI later); "2-minute start" button |
| Time blindness | Visual timer + Live Activity countdown on lock screen and Dynamic Island |
| Forgetting | Gentle repeating nudges until done or snoozed |
| Racing thoughts | Brain dump inbox: thoughts, not tasks, no structure required |
| Guilt and shame | Auto rollover, no overdue badges, "fresh start" button |
| Low/variable energy | Energy tags and "I'm low on energy" filter |
| Losing motivation | Satisfying animations, haptics, daily "done" list (what you *did* do) |

---

## MVP (v1.0) — prioritized

1. **Brain dump inbox** (thoughts + tasks) ✅ scaffolded
2. **Lock screen widget, check off from lock screen** ✅ scaffolded → redesign to "one next task" focus
3. **Personal / Work modes** ✅ scaffolded
4. **"Just one thing" focus screen**: big single task, done / skip / break down
5. **Break into steps**: subtasks, widget shows the current step
6. **Visual focus timer + Live Activity** (lock screen countdown)
7. **No-shame rollover** ✅: no dates, no overdue. Unfinished tasks just stay. On a new day a gentle card says what came along and offers to park some in **Later** (a quiet, collapsed bucket the widget and focus mode ignore). "Fresh start" parks everything in one tap. "Done today" resets at midnight.
8. **Satisfying check-off** (animation + haptics) and a "Done today" list ✅
9. **Pro subscription** (StoreKit 2) with free trial ✅ code done. Calm & Soft paywall, shown only when tapping a Pro feature or "Try Pro" in Settings. v1.0 gates the focus timer + Live Activity only.

## v1.1 — Couples (big launch update)

> **"Stop nagging. Let the lock screen remind them."**

- [ ] Shared space with a partner (or roommate / family), next to your private lists
- [ ] Partner adds a reminder → shows up as a gentle nudge on your lock screen
- [ ] Accept / snooze / decline shared tasks — the person with ADHD stays in control
- [ ] Private stays private; no "they haven't done it yet" surveillance
- [ ] Kind tone: "Alex added a reminder 💛", never "OVERDUE"
- [ ] Couples plan: one subscription covers two people (~$49.99/yr)
- [ ] Invite flow as a built-in growth loop
- Tech: CloudKit sharing or own backend (decide before v1.1)

## v1.x

- Gentle repeating nudges (notifications that come back until handled)
- Energy tags + low-energy filter
- AI step breakdown ("Clean the kitchen" → 5 tiny steps)
- Routines (morning / evening checklists)
- Lock screen wallpaper generator with your next task
- Focus Filters (iOS Focus integration) and auto-switch Personal/Work
- Siri / Shortcuts / Action Button capture
- iCloud sync
- Norwegian localization

## Later

- Body doubling ("work alongside" sessions)
- Apple Watch: next task + check off from wrist
- Shared lists / family plan

---

## Monetization

**Freemium + subscription.** No ads.

| Free | Pro (~$4.99/mo or ~$34.99/yr) |
|---|---|
| Brain dump inbox, unlimited tasks | Focus timer + Live Activities |
| Lock screen widget (one task) | All widget sizes and styles |
| Basic focus mode | Break into steps (unlimited), AI breakdown |
| | Gentle nudges, routines, energy filter |
| | Wallpaper generator + themes |

Extras: lifetime purchase (~$79.99), 7-day free trial.

**v1.0 gating:** only the focus timer + Live Activity is Pro. Steps, widgets and rollover stay free.

### Pro setup checklist (App Store Connect, once the developer account is approved)

| Product ID | Type | Price | Notes |
|---|---|---|---|
| `com.erijako.todoapp.pro.yearly` | Auto-renewable, group "Pro" | $34.99/yr | Introductory offer: 7-day free trial |
| `com.erijako.todoapp.pro.monthly` | Auto-renewable, group "Pro" | $4.99/mo | No trial |
| `com.erijako.todoapp.pro.lifetime` | Non-consumable | $79.99 | |

- [ ] Sign the Paid Applications agreement and add banking + tax info (products won't load until this is done)
- [ ] Create the subscription group "Pro" and the three products above (IDs must match `TodoApp/Pro/ProStore.swift`)
- [ ] Host a real privacy policy and update `Legal.privacy` in `ProStore.swift`
- [ ] Add a sandbox tester and test buy, restore and cancel via TestFlight
- Local testing in Xcode uses `StoreKit/Products.storekit` (already set in the scheme)

## Go-to-market

- Short-form video (TikTok / Reels / Shorts): "my lock screen fixed my ADHD to-do list" — the product is visual, so demo it
- Build in public; collect a waitlist before launch
- Talk to people with ADHD early (respect community rules — no spam in r/ADHD etc.)
- App Store keywords: ADHD planner, brain dump, focus, lock screen to-do
- Competitors to study: Tiimo, Structured, Goblin Tools, Routinery, Inflow

---

## Design

"Calm & Soft": fog background, white rounded cards, periwinkle accent, sage (personal), peach (thoughts), SF Pro Rounded. Never red, never "overdue". Tokens live in `Shared/Theme.swift`.

Mockups: https://claude.ai/artifact/8pivoN64YcqF1f5miS95th

## Tech stack

- SwiftUI, SwiftData (CloudKit sync later)
- WidgetKit + App Intents, ActivityKit
- StoreKit 2
- String Catalogs for localization (en, nb later)
- XcodeGen for project generation (no Mac required)
- GitHub Actions (`macos-15-intel` runner) → TestFlight
