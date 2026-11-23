# Feature List

> **Pitch:** Empty your head in 2 seconds, and keep what matters visible where you look most — your lock screen.

Platform: **iOS first** (native SwiftUI). Language: **English** by default, **Norwegian** later.

---

## 1. Lock screen (core differentiator)

- [ ] Lock screen widget showing top 1–3 tasks (WidgetKit, accessory families)
- [ ] Check off tasks directly from the widget (interactive widgets, App Intents, iOS 17+)
- [ ] Live Activity / Dynamic Island: "Working on…" with timer (ActivityKit)
- [ ] Generated wallpaper with your task list (via Shortcuts automation) + premium themes
- [ ] StandBy mode support

## 2. Capture thoughts fast

- [ ] Quick inbox: type without choosing a list, sort later
- [ ] Thought vs. task: not everything needs doing — keep ideas as notes
- [ ] Natural language dates ("call dentist friday")
- [ ] Voice to task
- [ ] Share extension: links, mail, screenshots into the inbox
- [ ] Action Button / Control Center control for one-tap capture
- [ ] Weekly review: "You have 12 unsorted thoughts — sort them?"

## 3. Personal vs. work

- [ ] Modes: Personal / Work / All — lock screen shows the right list
- [ ] Auto-switch by time and location
- [ ] iOS Focus integration (Focus Filters)
- [ ] "Off work": hide work tasks on weekends and vacation

## 4. Smart features (Pro candidates)

- [ ] AI task breakdown ("Plan birthday party" → subtasks)
- [ ] Energy level tags (low / high) and "I'm tired" filter
- [ ] "What should I do now?" — one suggested task based on time, place, deadlines
- [ ] Calendar view, drag tasks into free slots
- [ ] Flexible recurring tasks ("every 3rd week", "last Friday of the month")
- [ ] Evening recap: what got done, what moves to tomorrow

## 5. Sharing (growth + revenue)

- [ ] Shared lists (groceries, household)
- [ ] Family plan
- [ ] Small-team version (later)

## 6. Polish

- [ ] Themes and alternate app icons
- [ ] Optional streaks and stats
- [ ] Dark mode, Dynamic Type, VoiceOver
- [ ] Apple Watch: check off from wrist
- [ ] Siri: "Add milk to my grocery list"
- [ ] iCloud sync across iPhone / iPad / Mac

---

## Monetization

**Freemium + subscription.** No ads.

| Free | Pro (~$4.99/mo or ~$29.99/yr) |
|---|---|
| Unlimited tasks | Personal/Work modes with auto-switch |
| 1 lock screen widget | All widgets + Live Activities |
| Quick inbox | Wallpaper generator + themes |
| 3 lists | AI features, voice to task |
| | Unlimited lists, sharing, sync |

Extras:
- Lifetime purchase (~$59.99)
- Family plan (~$49.99/yr, up to 5 people)
- Theme packs as one-time purchases
- 7–14 day free Pro trial on first launch

---

## MVP (v1.0)

1. Quick inbox + lists
2. Personal / Work modes (manual switch)
3. **Interactive lock screen widget** ← core
4. Due dates and reminders
5. Pro subscription with 2–3 paid features

## Tech stack

- SwiftUI, SwiftData (CloudKit sync later)
- WidgetKit + App Intents, ActivityKit
- StoreKit 2
- String Catalogs for localization (en, nb later)
- XcodeGen for project generation (no Mac required)
- GitHub Actions macOS runners → TestFlight
