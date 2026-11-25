# Onestep: guide for collaborators

Onestep is an iOS to-do app built for ADHD brains. Pitch: *"Out of sight, out of mind — so we
put your next step where you look 100 times a day: your lock screen."* The lock screen widget
shows **one** next step, which you can check off without unlocking.

Read these first:
- `FEATURES.md`: product vision, feature list, monetization, roadmap
- `docs/STATUS.md`: what works, what's half-done, known bugs, next tasks
- `docs/DECISIONS.md`: every decision made so far, with the reasons and the rejected options
- Design canvas (mockups, onboarding, brand board): https://claude.ai/artifact/8pivoN64YcqF1f5miS95th

**Keep `docs/STATUS.md` and `docs/DECISIONS.md` up to date** whenever a task is finished or a
decision is made, in the same commit as the work.

## Stack

- **SwiftUI + SwiftData**, iOS 17+, iPhone only, Swift 5 language mode
- **WidgetKit + App Intents**: lock screen / home screen widget with an interactive check-off
- **ActivityKit**: focus timer Live Activity and Dynamic Island
- **StoreKit 2**: Pro subscription, verified on device (no server)
- **XcodeGen**: `project.yml` is the source of truth; `*.xcodeproj` is generated and git-ignored
- **GitHub Actions instead of a Mac**: the owner has no Mac. CI builds every push.

## Layout

| Path | What |
|---|---|
| `project.yml` | XcodeGen spec: targets, bundle IDs, entitlements, Info.plist keys |
| `Shared/` | Compiled into **both** app and widget: model (`TaskItem`, `TaskStep`, `FocusEngine`), `SharedStore` (App Group container, deep links), `Theme`, `ToggleTaskIntent`, `FocusActivity` |
| `TodoApp/` | The app: list (`ContentView`), focus mode, task detail, rollover (`NewDay`), `Onboarding/`, `Pro/` (store + paywall), Settings, focus timer controller |
| `TodoWidget/` | Widget extension: `TasksWidget` (Up Next) and `FocusLiveActivity` |
| `StoreKit/Products.storekit` | Local StoreKit test config (wired into the scheme) |
| `design/make_icon.py` | Generates the app icon (light + dark) with Pillow + NumPy |
| `docs/` | `privacy.html` (GitHub Pages), `testflight.md`, `STATUS.md`, `DECISIONS.md`, `SHARING_SPEC.md` (v1.1) |
| `.github/workflows/` | `ios-build.yml` (every push), `testflight.yml` (off until account approval) |
| `.claude/skills/` | Third-party skills: startup-design etc. (MIT), impeccable (design review, Apache 2.0) |

The folder and target are still named `TodoApp` internally; only the display name, bundle IDs and
URL scheme were renamed to Onestep. Don't rename folders without a reason.

## Build and test

There is no local Xcode in the Linux dev container. **Push and check CI**:

1. Commit and push to the working branch.
2. Check the "iOS Build" run (GitHub MCP: `actions_list` → `list_workflow_runs` for the branch,
   then `get_job_logs` on failure). A build takes about 3 minutes.
3. Fix any `error:` lines and push again. Never leave the branch red.

What CI runs (also works on a Mac):

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project TodoApp.xcodeproj -scheme TodoApp -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

There are **no unit tests yet** (see STATUS). Regenerate the icon with `python3 design/make_icon.py`.

## Code conventions

- **Colors, radii and type only from `Shared/Theme.swift`.** Every color has light + dark values.
  Shapes: `Theme.Radius.card` (24), `Theme.Radius.control` (16), or `Capsule()`. Type sizes:
  `.largeTitle`, `.title3`, `.body`, `.footnote` (+ `EyebrowText` for small uppercase labels).
  App views use `.fontDesign(.rounded)`.
- **Never red, never "overdue", never streaks or guilt.** Unfinished tasks just stay.
- **Voice: "kind friend"**: short, warm, a little funny. "Not your problem right now."
  Never medical claims: "built for ADHD brains", not "treats ADHD".
- **Contrast:** text at least 4.5:1, controls 3:1 (checked for the tokens already).
- **One source of truth for "next"**: `FocusEngine.openTasks/next` (pinned first, then `sortOrder`;
  thoughts, done and Later tasks excluded). The app, widget and Live Activity all use it.
- **After changing data, call `context.saveAndRefresh()`** so widgets reload.
- **SwiftData model stays CloudKit-friendly**: every property has a default, relationships are
  optional. New properties need defaults (lightweight migration).
- **Swipes**: leading = move up (pin, bring back, make task); trailing = move down (Later, delete).
  **A full swipe must never delete** (`allowsFullSwipe: false` where delete is first).
- **Pro gating**: read `@Environment(ProStore.self)`; show the paywall only when a locked feature is
  tapped or from Settings. Product IDs live in `ProProduct` and must match App Store Connect and
  `StoreKit/Products.storekit`.
- **Accessibility**: real buttons, labels on icon-only buttons, 44pt touch targets.
- **Strings**: write user-facing text as `LocalizedStringKey` / `String(localized:)` (String
  Catalogs; Norwegian comes later).
- iOS 18-only APIs behind `if #available(iOS 18.0, *)` (see `focusZoomSource`).

## Working rules

- Work on branch `claude/wizardly-goldberg-ueg1u0` unless told otherwise. Don't open PRs unless asked.
- After every push, check the CI build and fix failures before moving on.
- Ask the owner before product decisions that aren't settled in `docs/DECISIONS.md`.
- Mockups first for new screens (design canvas), then code.
- Commit messages: imperative summary + short bullet body. No model names in commits or code.
- Never commit secrets. TestFlight secrets live in GitHub Actions secrets (see `docs/testflight.md`).
