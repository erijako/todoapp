# TestFlight setup (do this once Apple approves the developer account)

The workflow `.github/workflows/testflight.yml` archives a signed build and uploads it to
TestFlight. It is switched off until you complete the steps below. No Mac needed.

## 1. Before the first upload

- [ ] **Final app name and bundle ID.** Change `com.erijako.todoapp` in `project.yml`
      *before* the first upload if you want a different one. It can't be changed later.
- [ ] **App icon.** A 1024×1024 PNG in `TodoApp/Assets.xcassets/AppIcon.appiconset`.
      Uploads are rejected without one.
- [ ] **Privacy policy URL** live (see `docs/privacy.html`).

## 2. App Store Connect (appstoreconnect.apple.com)

1. **Create the app.** Apps → "+" → New App. Platform iOS, bundle ID
   `com.erijako.todoapp` (register it first under Certificates, IDs & Profiles → Identifiers
   if it isn't in the list; add the **App Groups** capability with `group.com.erijako.todoapp`).
   Also register `com.erijako.todoapp.widget` with the same App Group.
2. **Create an API key.** Users and Access → Integrations → App Store Connect API →
   Team Keys → "+". Name it "GitHub Actions", access **Admin** (needed so the build can
   create signing certificates automatically). Download the `.p8` file (only possible once)
   and note the **Key ID** and **Issuer ID**.
3. **Team ID.** developer.apple.com → Account → Membership details.

## 3. GitHub (repo → Settings → Secrets and variables → Actions)

Secrets:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Team ID |
| `ASC_KEY_ID` | The API key's Key ID |
| `ASC_ISSUER_ID` | The Issuer ID |
| `ASC_KEY_P8` | The full text of the `.p8` file, including the BEGIN/END lines |

Variables tab: add `TESTFLIGHT_ENABLED` = `true`.

## 4. Upload

Actions → TestFlight → Run workflow (or push a tag like `v0.1.0`). After about 15 minutes
of processing the build shows up in App Store Connect → TestFlight. Add yourself as an
internal tester and install it with the TestFlight app on your iPhone.

Build numbers come from the GitHub run number, so every upload is unique automatically.
Bump `MARKETING_VERSION` in `project.yml` for new versions.

## If it fails

- *"No profiles for … were found"*: the bundle IDs or App Group aren't registered yet (step 2.1).
- *"Cloud signing permission error"*: the API key needs the Admin role.
- *Missing app icon*: see step 1.
