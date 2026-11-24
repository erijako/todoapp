# Decisions

Each entry: what we decided, why, and what we rejected. Newest topics at the bottom of each
section. Update this file whenever a decision is made.

## Product and positioning

**Niche: ADHD brains, iOS first.**
Why: a crowded general to-do market vs. a clear, underserved pain (out of sight, out of mind).
The lock screen is the differentiator.
Rejected: a general-purpose to-do app; Android or cross-platform first.

**One next step, not a list, on the lock screen.**
Why: overwhelm and task paralysis. Show the next step, not the mountain.
Rejected: a widget listing several tasks (that's every other app).

**Personal / Work modes.** Two separate lists with a switch; the widget follows the current mode.

**No medical claims.** "Built for ADHD brains", never "treats ADHD" (App Review and honesty).

**English first, Norwegian later** via String Catalogs.

## Platform and tooling

**Native SwiftUI + SwiftData + WidgetKit + ActivityKit.**
Why: lock screen widgets, interactive App Intents and Live Activities need native iOS.
Rejected: React Native / Flutter (worse widget and Live Activity support).

**Xcode 26 in CI** (selected per run): App Store Connect requires the iOS 26 SDK for uploads
(iOS 27 SDK from April 2027). iPhone only: `TARGETED_DEVICE_FAMILY: "1"` is set on each target,
because XcodeGen's target defaults override the project-level value.

**No Mac: XcodeGen + GitHub Actions.**
Why: the owner has no Mac. `project.yml` generates the Xcode project in CI; every push builds
unsigned for the simulator.
Runner: `macos-15-intel` because the arm64 runners were capacity-constrained.
Rejected: committing a hand-made `.xcodeproj` (unmaintainable without Xcode); renting a Mac.

**TestFlight from GitHub Actions with an App Store Connect API key, temporary signing per run.**
The archive is ad-hoc signed (keeps the App Group entitlement, needs no certificate). A Ruby script
(`.github/scripts/asc_signing.rb`) creates a distribution certificate and App Store profiles through
the API, the export is signed with them, `altool` uploads, and the certificate is revoked and the
profiles deleted at the end. Runs only when the `TESTFLIGHT_ENABLED` repo variable is `true`.
Rejected after trying: automatic signing in the archive (fresh runners lose the development
certificate's private key, so Apple refuses a new one) and cloud-managed signing on export
("Authentication failed"). Also rejected: fastlane match (needs a certificates repo) and storing a
.p12 in secrets (needs a Mac or manual key handling).

**Data stays on device.** SwiftData in an App Group container shared with the widget.
No accounts, no servers, no analytics. Privacy label: Data Not Collected.

## Design

**"Calm & Soft" design system** (`Shared/Theme.swift`): fog background, white cards, periwinkle
accent, peach for thoughts, sage for calm hints, SF Pro Rounded. Light and dark.
Rejected: bold/high-energy styles (too stimulating for the audience).

**Never red, never "overdue".** Core to the no-shame principle.

**Design review (Design Council) fixes:** radii collapsed to 24 / 16 / pill; type reduced to four
sizes; darker unchecked circle and peach text for contrast; the "Up next" task is not repeated in
the list; a long swipe never deletes; Done today shows a dot counter; Up next zooms into focus
mode (iOS 18).

**Mockups use SF Pro Rounded** (Nunito only as a fallback for non-Apple viewers), matching the app.

## Features

**Brain dump with thoughts.** Tasks and loose thoughts in one inbox; thoughts never become "next"
unless turned into a task.

**No-shame rollover = "daily fresh start", no dates.**
Unfinished tasks just stay. On a new day a card shows what came along and offers to park some in
**Later** (a collapsed bucket that focus mode and the widget ignore). "Fresh start" parks everything
in one tap. "Done today" resets at midnight.
Rejected: Today + Later lists with scheduling; optional due dates with silent move-to-today
(more structure and UI, closer to classic apps). The unused `dueDate` field is kept for later.

**Onboarding: 5 screens, skippable** — Welcome → Brain dump → Pick the one (pinned) → Lock screen
widget guide (with live detection via `WidgetCenter`, "Found it") → You're set (empty variant
after Skip). Real tasks are created during onboarding so the widget shows something real.
Rejected: a notification soft-ask screen (in v1.0 the only notification is the Pro timer's
"time's up", so free users would grant something they never use). Permission is asked when the
first timer starts.

## Monetization

**Freemium + subscription, no ads.** Pro $4.99/mo, $34.99/yr with a 7-day free trial (yearly
only), $79.99 lifetime. Product IDs `com.erijako.onestep.pro.{monthly,yearly,lifetime}`, group "Pro".
Rejected: trial on monthly too; subscriptions only (no lifetime).

**v1.0 gates only the focus timer + Live Activity.** Steps, widgets and rollover stay free.
Rejected: limiting steps to 3 per task; gating home screen widgets; gating Fresh start/Later
(no-shame is core and must stay free). Known risk: Pro is thin; gentle nudges are the planned
second Pro feature.

**Paywall only when a Pro feature is tapped** (plus "Try Pro" in Settings). Honest design: close
button always visible, full price wording, no countdowns. Benefits list only what Pro adds
(removed "check off from lock screen" and "ad-free", which free users already have).
Rejected: showing the paywall after onboarding.

**StoreKit 2, on-device verification, no server.**

## Naming and brand

**Name: Onestep.** Bundle `com.erijako.onestep`, App Group `group.com.erijako.onestep`, URL scheme
`onestep://`. "OneStep" alone is taken on the App Store (weight loss, physical therapy apps), so the
store name is "Onestep: Gentle To-Do List" ("ADHD" kept out of the name so it never labels users; it goes in the hidden keywords).
Rejected: Lockstep, Glance, Tiny Steps; store names with "ADHD" in them.

**Brand: "the warm stone"** — a stepping stone with a warm peach light inside, on calm periwinkle
water (dark version on night blue). Story: you don't cross the river at once; you find the next
stone, and it glows a little. Personality: "kind friend". Wordmark: lowercase "onestep", heavy.
The glow color is reserved for the one next thing.
Rejected: a checkmark icon (too generic); the path of stones, a plain glowing dot, a mascot.

## Legal

**Privacy policy hosted on GitHub Pages** (`docs/privacy.html`), covering v1.0 only; to be updated
before iCloud sync or Couples ships. Terms: Apple's standard EULA.

## v1.1 Couples (planned)

**Lean: CloudKit sharing** (Apple ID identity, no accounts, no server, no running costs).
Shared data needs `CKSyncEngine` or Core Data, since SwiftData doesn't sync shared databases.
Alternative kept open: own backend (Supabase etc.), needed only for cross-platform partners.
Not decided yet.
