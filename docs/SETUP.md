# Build and release setup (no Mac needed)

The app is built in the cloud by GitHub Actions on a macOS runner and uploaded
to TestFlight. Paul installs each build from the TestFlight app on his iPhone.

## Accounts (Paul)

- [ ] GitHub account (free).
- [ ] Apple Developer Program membership (paid, yearly), using his personal
      Apple ID, not a work one.
- [ ] Connect GitHub to Claude so Claude Code can work on the repository.
- [ ] Install TestFlight on the iPhone.

## One-off Apple setup (Claude Code walks Paul through it)

1. In App Store Connect, create the app record (name, bundle ID such as
   `com.<paul>.podcasts`).
2. Create an App Store Connect API key (Users and Access → Integrations),
   with App Manager access. Note the Key ID and Issuer ID and download the
   `.p8` file once.
3. Let the CI create and manage signing using that API key (automatic
   signing via `xcodebuild -allowProvisioningUpdates` with the API key, or
   fastlane match). No Mac keychain needed.
4. iCloud sync (`Config/Podcasts.entitlements`): in Certificates,
   Identifiers & Profiles, turn on **iCloud** (with CloudKit) and **Push
   Notifications** for the app ID `com.gruffaluff.podcasts`, and create the
   iCloud container `iCloud.com.gruffaluff.podcasts`. Automatic signing
   with `-allowProvisioningUpdates` can do this itself.
5. CloudKit schema (no Mac needed): the entitlements start with
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

- Workflow `.github/workflows/testflight.yml` on a `macos` runner:
  checkout → select latest Xcode → resolve packages → run unit tests →
  archive with automatic signing → export IPA → upload to TestFlight
  (`xcrun altool` / `notarytool` successor or fastlane `pilot`).
- Trigger: push to `main` (and manual "Run workflow").
- Build number: use the GitHub run number.
- Expect roughly 15–30 minutes from push to TestFlight availability.
- macOS runner minutes count more heavily against GitHub's free allowance;
  keep builds to merges into `main`.

## Project generation

Because no one opens Xcode, generate the project from a text spec
(e.g. XcodeGen `project.yml` or a Swift Package-based app target) so every
change is a reviewable text diff.
