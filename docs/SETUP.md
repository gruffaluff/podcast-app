# Build and release setup (no Mac needed)

The app is built in the cloud by GitHub Actions on a macOS runner and uploaded
to TestFlight. Paul installs each build from the TestFlight app on his iPhone.

## Accounts (Paul)

- [ ] GitHub account (free).
- [ ] Apple Developer Program membership (paid, yearly), using his personal
      Apple ID, not a work one.
- [ ] Connect GitHub to Claude so Claude Code can work on the repository.
- [ ] Install TestFlight on the iPhone.

## One-off Apple setup (Paul, in a web browser, about 20 minutes)

Apple names used: bundle ID `com.gruffaluff.podcasts`, iCloud container
`iCloud.com.gruffaluff.podcasts`, app name **Poddeck** (fallback
"Poddeck Player" if taken).

1. **Team ID**: developer.apple.com → Account → Membership details →
   copy the 10-character **Team ID**.
2. **iCloud container**: developer.apple.com → Certificates, Identifiers &
   Profiles → Identifiers → **+** → iCloud Containers → description
   "Poddeck", identifier `iCloud.com.gruffaluff.podcasts`.
3. **App ID**: Identifiers → **+** → App IDs → App → description
   "Poddeck", Bundle ID **Explicit** `com.gruffaluff.podcasts`. Under
   Capabilities tick **iCloud** (choose "Include CloudKit support") and
   **Push Notifications**. Save, then open it again, click **Configure**
   next to iCloud, tick the container from step 2, save.
4. **App record**: appstoreconnect.apple.com → Apps → **+** → New App →
   iOS, name **Poddeck**, primary language English (U.K.), bundle ID from
   step 3, SKU `poddeck`, user access Full Access.
5. **API key**: App Store Connect → Users and Access → Integrations →
   App Store Connect API → Team Keys → **+** → name "GitHub", access
   **Admin** (needed so the build machine can make signing certificates).
   Download the `.p8` file (only possible once) and note the **Key ID**
   and the **Issuer ID** shown above the list.
6. **GitHub secrets**: github.com/gruffaluff/podcast-app → Settings →
   Secrets and variables → Actions → New repository secret, four times
   (table below). For `ASC_KEY_P8` open the `.p8` file in a text editor
   and paste everything, including the BEGIN/END lines.
7. **TestFlight**: after the first upload has processed, App Store
   Connect → Poddeck → TestFlight → Internal Testing → **+** → group
   "Me", add yourself. Install the TestFlight app on the iPhone and
   accept the invite.

Signing is automatic: the TestFlight workflow signs with the API key
(`xcodebuild -allowProvisioningUpdates`), so no Mac keychain or
certificate files are needed.

### After the first build: iCloud database (one-off)

iCloud sync uses `Config/Podcasts.entitlements` (CloudKit container, push,
key-value storage); steps 2–3 above set up the Apple side. CloudKit schema
(no Mac needed): the entitlements start with
   `com.apple.developer.icloud-container-environment` = Development, so the
   first TestFlight build creates the record types (CD_Podcast,
   CD_PodcastEpisode, CD_UpNextEntry, CD_Bookmark) as it saves. Once Paul
   has used it a little, sign in to the CloudKit Console
   (icloud.developer.apple.com), check the record types exist, and
   **Deploy Schema Changes** to Production. Then change the entitlement to
   Production and ship the next build. Do this again (deploy first) after
   any change to the SwiftData models in `App/Models.swift`. Note: data
   saved while on Development doesn't move to Production by itself; after
   switching, check in the CloudKit Console that the phone's library has
   arrived in Production.

## GitHub repository secrets

Add these under Settings → Secrets and variables → Actions:

| Secret | What it is |
|---|---|
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_P8` | Contents of the `.p8` key file |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

Never commit any of these values to the repository.

## Pipeline

- `.github/workflows/testflight.yml` on `macos-15-intel` (the Apple-silicon
  machines are often unavailable): newest Xcode → XcodeGen → archive with
  automatic signing via the API key → export with
  `Config/ExportOptions.plist` (method app-store-connect, destination
  upload), which uploads straight to TestFlight.
- Trigger: push to `main` (and manual "Run workflow"). Without the secrets
  it stops with a note instead of failing.
- Build number: the TestFlight workflow's run number; version 0.1.
- Minimum iOS is 26.0 because the build machines have the iOS 26.2 SDK
  (Apple accepts iOS 26 SDK builds); it runs on Paul's iOS 27.2 iPhone.
- `App/PrivacyInfo.xcprivacy` declares no tracking and the UserDefaults
  reason Apple requires.
- Expect roughly 15–30 minutes from push to TestFlight availability.
- macOS runner minutes count more heavily against GitHub's free allowance;
  keep builds to merges into `main`.

## Project generation

Because no one opens Xcode, generate the project from a text spec
(e.g. XcodeGen `project.yml` or a Swift Package-based app target) so every
change is a reviewable text diff.
