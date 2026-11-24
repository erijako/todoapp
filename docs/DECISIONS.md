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

**"Simulate purchase" for testing (2026-11-24)**: a button on the paywall unlocks Pro without the
App Store, so Pro features can be tested before the products exist in App Store Connect. Shown only
in Debug builds and in non-production installs (TestFlight, Xcode, sandbox, via
`AppTransaction.environment`); ignored in the App Store version even if the flag is set.
"Turn off simulated Pro" in Settings.

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

## v1.1 Sharing ("Couples", decided 2026-11-24)

**Technology: iCloud sharing (CloudKit).** Invite via an Apple share link; identity is the Apple ID.
No accounts, no server, no running costs; data stays in the users' iCloud. Both people need an
iPhone with iCloud. SwiftData can't sync shared databases, so the shared space uses `CKSyncEngine`
(or Core Data + `NSPersistentCloudKitContainer`); private lists stay on SwiftData.
Rejected: own backend (Supabase etc.): accounts, costs, larger GDPR scope; only needed for Android/web.

**Partner role: send gentle reminders.** A member adds a reminder for someone; it shows up as a
gentle nudge (and can reach the lock screen widget). The receiver accepts, snoozes or declines and
stays in control. Private lists stay private; no "they haven't done it yet" surveillance.
Kind tone: "Alex added a reminder 💛", never "OVERDUE".
Rejected: a shared list where everyone edits; doing both (about double the work).

**Group size: a few people** (partner, roommates, family; cap around 5), not just one partner.
Means: show who sent each reminder, per-sender display names, choose recipient when sending.
Rejected: exactly one partner.

**Pricing: free for now** (TestFlight and launch) to learn whether people use it; decide later
(options: Couples/Family plan ~$49.99/yr, or part of Pro).

Requires in the developer portal: iCloud (CloudKit) container `iCloud.com.erijako.onestep` on the
app's App ID, Push Notifications (CloudKit's silent pushes), plus Background Modes → Remote
notifications in the app. Privacy policy must be updated before this ships.

**Mockups approved 2026-11-24** (canvas row "v1.1 Sharing", S1–S7; spec in `docs/SHARING_SPEC.md`).
Details decided with them:
- **Sender sees only "got it" / "not this time"**, "Sent" otherwise. Snooze is invisible to the
  sender; completion is never shown or synced. Rejected: showing done status (surveillance).
- **A taken reminder never jumps the queue**: it becomes a normal Personal task at the end of the
  list and reaches the widget only when it becomes next the normal way.
  Rejected: pinning it or showing it on the widget straight away.
- **Entry point is an avatar button in the list header** (dot when something is new), not a third
  mode next to Personal/Work. Rejected: a "Shared" mode tab.
- **One shared space per person**, named by its creator, max 5 people.
  Rejected: several spaces (more UI, little need yet).
- **"Hand it back"** on a taken reminder returns it to the sender.
- **Copy: Take it / Later / Pass** (not Accept / Snooze / Decline); "Alex added a reminder" with a
  heart icon instead of the 💛 emoji.
- **Data**: whole-zone `CKShare` in the owner's private database; record types `Space`, `Member`,
  `Reminder` (one per recipient); `CKSyncEngine` with a small local Codable cache.
  Rejected: Core Data + `NSPersistentCloudKitContainer` (a second persistence stack for a few records).
- **Sync without `CKSyncEngine` (changed while building step 2)**: plain async CloudKit calls.
  Every refresh reads the whole zone (tiny data), local changes are marked dirty and saved with
  `.allKeys`; silent pushes (zone subscription for the owner, database subscription for members)
  trigger a refresh. Rejected: `CKSyncEngine` (state serialization and event handling for a few
  dozen records; harder to get right without a local Xcode).
- **Only the owner invites** (v1.1), from the shared space. Members see a kind note instead.
- **Entitlements land only after the portal setup**, because TestFlight export keeps the archive's
  entitlements and would fail on an App ID without iCloud/Push.
