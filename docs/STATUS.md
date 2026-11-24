# Status

Last updated: 2026-11-24. Update this file whenever something is finished.

Important caveat: **nothing has been tested on a real device yet** (first TestFlight build just uploaded). CI only proves the app
compiles. Everything below "works" in the sense that it is built and compiles cleanly.

## Built (compiles in CI)

- Brain dump inbox: tasks and thoughts, quick add bar
- Personal / Work modes (shared with the widget)
- Task steps ("break it down"), current step highlighted
- "Just one thing" focus mode: done / not now / break it down
- Pin as next; "Up next" card (tap for details, long-press menu)
- Done today with dot counter and haptics
- Lock screen + home screen widget "Up Next" with check-off from the lock screen
- Focus timer (2 / 10 / 25 min, +5) with Live Activity and Dynamic Island, "time's up" notification
- No-shame rollover: Later bucket, new-day card ("Park some"), Fresh start
- Pro: StoreKit 2 store, paywall, Settings (restore, manage subscription); timer gated
- First-launch onboarding (5 screens, widget detection, skip variants); widget guide in Settings
- Calm & Soft design system, light + dark
- Name Onestep, warm-stone app icon (light + dark)
- Privacy policy page (`docs/privacy.html`)
- TestFlight workflow (disabled) + setup guide (`docs/testflight.md`)
- Startup skills installed in `.claude/skills/`

## Half-done

- **Purchases untested**: needs App Store Connect products (after account approval) or a Mac with
  the StoreKit config.
- **Privacy policy**: `[DEVELOPER NAME]`, `[CONTACT EMAIL]`, `[DATE]` placeholders; GitHub Pages
  not turned on (serves from `main`, so this branch must be merged first; a private repo needs a
  paid plan). `Legal.privacy` already points to https://erijako.github.io/todoapp/privacy.html.
- **Brand not in the app yet**: screens and onboarding still use the plain Calm & Soft look; the warm
  stone and glow color only exist in the icon and on the canvas.
- **TestFlight**: account set up (App IDs, App Group, app record, API key, secrets, a device).
  **First build uploaded to TestFlight on 2026-11-24** (workflow run 7, built with Xcode 26).
  Next: install via TestFlight and test on a real iPhone. Building with the iOS 26 SDK gives
  system bars and controls the new "Liquid Glass" look; check it on device.
- **Localization**: some onboarding strings are built from `String` ternaries and won't be picked up
  by the String Catalog.

## Known bugs and risks (unverified, found by reading the code)

- Onboarding brain dump: the list's `ScrollView` takes a fixed 260 pt as soon as one item exists,
  leaving empty space.
- `UpNextCard` has a tap gesture (open details) around a "Focus" button; check that tapping Focus
  doesn't also open details.
- Debug "Show onboarding again" relies on `@AppStorage` in `ContentView` noticing the change; untested.
- Pro is thin (timer only) for $34.99/yr: business risk, not a code bug.
- No unit tests; regressions would only be caught by hand.

## Next 5 tasks (priority order)

1. **Sharing (v1.1):** mockups (canvas S1–S7) and spec (`docs/SHARING_SPEC.md`) approved
   2026-11-24. Next: build order step 1 (model, cache, `SharingStore`, screens with fake data),
   then CloudKit. Owner: portal setup (iCloud container + Push Notifications) before the
   entitlements commit.
2. **Validate the business idea** with `/startup-design` and adjust the plan.
3. **Gentle nudges** (Pro): local notifications that return until done or snoozed.
4. **Landing page + waitlist** on GitHub Pages in the brand style.
5. **Bring the brand into the app**, then **unit tests in CI**.

## Apple Developer account: approved 2026-11-24 (setup in progress)

Follow `docs/testflight.md`, then: Paid Applications agreement + bank/tax, create the three Pro
products, sandbox tester, first TestFlight build, fill in the privacy placeholders.
