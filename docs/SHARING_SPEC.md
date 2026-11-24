# v1.1 Sharing: spec

Status: mockups approved 2026-11-24 (design canvas, row "v1.1 Sharing", screens S1–S7).
Decisions and reasons: `docs/DECISIONS.md` → "v1.1 Sharing". This file says **what to build**.

## The idea in one line

A few people (up to 5) share a small space and toss each other gentle reminders. The receiver
takes it, saves it for later or passes. Nobody sees anyone's lists, and nobody sees whether
anything got done.

## Screens (canvas → SwiftUI)

| Canvas | View (planned) | Notes |
|---|---|---|
| S1 Start sharing | `Sharing/ShareStartView` (sheet) | Display name + space name, 3 promises, "Invite someone" opens the iCloud share sheet. Shown from the header button when you have no space yet. |
| S2 Invite received | `Sharing/ShareJoinView` (full-screen cover) | Shown when the app opens from an invite link (CKShare metadata), **before** accepting. "Join Home" accepts; "Not now" dismisses (link still works later). Lets you set your display name. |
| S3 Shared space | `Sharing/SharedSpaceView` (sheet) | Members grid (+ Invite slot while < 5), "Send a reminder", "For you" (pending incoming), "You sent" (outgoing with status). Menu: rename space, change my name, leave (participant) / stop sharing (owner). Neutral colors, never red. |
| S4 Send a reminder | `Sharing/SendReminderView` (sheet) | Recipient chips (multi-select, not yourself), title (required), note (optional), when: Now / This evening (18:00) / Tomorrow (09:00). Live preview. Send button disabled until someone is picked. |
| S5 Incoming card | `Sharing/IncomingReminderCard` in `ContentView` | Top of the list, above Up Next, one card at a time (oldest first, "+2 more" hint if several). Take it / Later (in an hour, tonight, tomorrow) / Pass, then a kind toast with Undo (about 5 s). |
| S6 Who sent it | additions to `TaskDetailView` | "From Alex" card with time + note, "What Alex sees" line, "Hand it back to Alex". Only for tasks that came from a reminder. |
| S7 Lock screen | local notification, category `REMINDER` | Title "Alex added a reminder", body = title + note. Actions: Take it / Tonight / Pass (no unlock needed for Tonight and Pass; Take it may open the app). |

Header entry point (S5): a small avatar-stack button next to the list title, with an accent dot
when something new is waiting. Without a space it shows a people icon that opens S1.

## Rules (approved)

1. **What the sender sees**: "Sam's got it" after Take it, "Not this time" after Pass, "Sent"
   otherwise. A snooze is invisible to the sender. Completion is **never** synced or shown.
2. **Reminders never take over Up Next.** Take it creates a normal `TaskItem` in **Personal**,
   added at the end of the open list (after pinned and existing tasks). It reaches the widget only
   when it becomes next the normal way.
3. **One shared space per person**, named by its creator, max 5 people (owner + 4).
4. **Hand it back** (from S6): deletes your local task and marks the reminder `handedBack`; the
   sender gets it in "For you" as "Jo handed it back" with Take it / Pass.
5. **Copy**: Take it / Later / Pass; "Alex added a reminder" with a heart icon (no emoji in UI).
   Voice: kind friend. Never "overdue", never red.
6. Passed, taken and handed-back reminders disappear from "For you" for the receiver. "You sent"
   shows the last 14 days.

## Data model

Two worlds, on purpose:

- **Private lists stay on SwiftData** (unchanged, local only for now).
- **The shared space lives in CloudKit**, synced with `CKSyncEngine` (iOS 17+), cached locally in
  a small Codable file in the App Group container. SwiftData can't sync shared databases.

### CloudKit layout

- Container: `iCloud.com.erijako.onestep`.
- The owner creates a custom zone `Space-<uuid>` in their **private** database and shares the
  **whole zone** (`CKShare(recordZoneID:)`, participants read-write, `publicPermission = .none`).
- Participants see the same zone in their **shared** database.
- One `CKSyncEngine` per database: the private engine (owner) and the shared engine (members).
  Persist each engine's `stateSerialization` next to the cache.

### Record types (all in the space zone)

| Type | Fields | Written by |
|---|---|---|
| `Space` (one, record name `space`) | `name` String | owner |
| `Member` (record name = member id) | `displayName` String, `colorIndex` Int64, `joinedAt` Date | each person writes their own |
| `Reminder` (record name = UUID) | `title` String, `note` String, `senderID` String, `recipientID` String, `showAt` Date, `state` String (`sent`/`taken`/`passed`/`handedBack`), `createdAt` Date, `answeredAt` Date? | sender creates; recipient changes `state` |

- **Member id**: the person's CloudKit user record name (`CKContainer.userRecordID()`), so it is
  stable across devices and matches `CKShare.Participant.userIdentity.userRecordID`.
- **One record per recipient** (sending to Alex & Sam makes two records), so each state is simple.
- Avatar colors: 4 soft pairs (peach, green, indigo, lilac, as on the canvas) added to
  `Theme` with light + dark values; `colorIndex` picks one, assigned in join order.

### Local-only data

- Snooze: `snoozedUntil` per reminder id, stored only in the local cache (never synced).
- `TaskItem` gains (with defaults, CloudKit-friendly): `fromReminderID: String?`,
  `fromName: String?`, `fromNote: String?`, `fromSentAt: Date?`. Used by S6 and for Hand it back.

## Flows

**Invite (owner)**: S1 → create zone + `Space` + own `Member` + `CKShare` → save → present the
share sheet (`UICloudSharingController` wrapped for SwiftUI, or `ShareLink` with
`CKShareTransferRepresentation`). Invite more from S3 the same way. Block at 5 people.

**Join (member)**: tapping the link opens the app with `CKShare.Metadata`
(`UIWindowSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:)`, via an app/scene delegate
adaptor; Info.plist `CKSharingSupported = YES`) → S2 → "Join Home" runs `CKAcceptSharesOperation`,
writes own `Member`, starts the shared engine. If you are already in a space: friendly message
"You're already in Home. Leave it first to join this one." (one space per person).

**Send**: S4 → one `Reminder` per recipient, `state = sent` → sync.

**Receive**: on fetch, new `Reminder` with `recipientID == me` and `state == sent`:
- if `showAt <= now`: show card + post a local notification;
- else schedule a local notification at `showAt`; the card appears from then.

**Answer**: Take it → create `TaskItem` (Personal, at the end) + `state = taken` +
`saveAndRefresh()`. Later → local `snoozedUntil` + local notification then. Pass → `state = passed`.
Undo within the toast reverts both locally and in CloudKit.

**Leave / stop sharing**: member: delete own `Member`, remove self from the share, clear the cache.
Owner: delete the zone (ends the space for everyone; confirm first with kind copy).

## Notifications: known risk

CloudKit pushes for `CKSyncEngine` are **silent**; iOS may delay background fetches. So, besides
the engine's own subscription, add a **visible** fallback: a `CKDatabaseSubscription` on the shared
database (members) and a zone subscription in the private database (owner) with
`notificationInfo.alertBody` like "Someone in Home added a reminder" (no names possible
server-side). When the app can fetch in time, it posts the richer local notification
instead. Must be tested on two real devices.

Notification permission: asked the first time you join or create a space (with a one-line
reason), not at launch.

## Setup outside the code (owner, Apple Developer portal)

1. App ID `com.erijako.onestep`: enable **iCloud** (CloudKit) and **Push Notifications**.
2. Create the container `iCloud.com.erijako.onestep` and assign it to the App ID.
3. Then add to `project.yml` (app target only): entitlements
   `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services: [CloudKit]`,
   `aps-environment`, and Info.plist `UIBackgroundModes: [remote-notification]`, `CKSharingSupported: true`.
4. After the first run, deploy the CloudKit schema from Development to Production in the
   CloudKit Console before a TestFlight/App Store build uses it.

**Order matters**: the TestFlight workflow keeps the archive's entitlements and signs via the API,
so adding the iCloud/push entitlements **before** step 1–2 would break TestFlight export. The code
is built first without them (CloudKit calls then fail softly and Sharing shows "Sharing needs
iCloud" copy); the entitlements commit lands after the portal steps.

## Out of scope for v1.1

Android/web, editing someone else's lists, completion status, streaks or stats, reminders
on the widget before you take them, multiple spaces, chat or reactions, a thank-you heart.

## Build order

1. Model + cache + `SharingStore` (@Observable, no CloudKit yet), screens S1, S3–S6 with fake data
   behind a DEBUG switch. CI green.
2. CloudKit: zone, records, `CKSyncEngine` for both databases, invite + accept (S2). CI green.
3. Notifications (local + categories + fallback subscriptions).
4. Portal setup (owner) → entitlements commit → TestFlight → test on two iPhones.
5. Privacy policy update (iCloud sharing, display names), then ship.
