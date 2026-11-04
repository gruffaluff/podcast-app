# Podcast app — project brief

Read this first in every session. It records what Paul (the owner) has decided.
Keep it up to date when decisions change. Detailed look and screen specs are in
`docs/DESIGN.md`; the build and release pipeline is in `docs/SETUP.md`; the
original screen mockups are in `design/`.

## What this is

**Poddeck** (Paul's name, Nov 2026, to fit the Tape Deck look; it was
"Podspot", but "PodSpot: Find My Headphones" already exists on the App
Store and app names must be unique. If "Poddeck" turns out to be taken in
App Store Connect, register "Poddeck Player" and keep "Poddeck" on the home
screen. Icon: **option D, a cassette** (ink shell, orange label, two lit
reels on the grey panel), drawn by `design/icon/make_deck_icon.py`; options
in `design/icon/deck_options.png`. Earlier Podspot icons: `make_icon.py`,
`options.png`). A personal iOS podcast app for Paul's own iPhone, delivered through TestFlight.
It combines the best parts of Apple Podcasts, Spotify, Pocket Casts and
Overcast. Goal: **minimal to look at, fully functional underneath**.

**Look: "Tape Deck"** (Paul's pick, Nov 2026, from three redesigns on the
canvas https://claude.ai/artifact/RgNB6YCQMCdk9XdPfpiaTL; replaces the
original warm off-white / serif / terracotta look). Warm grey device panels,
ink black, one orange accent for keys, monospaced titles, labels and times
(iOS's SF Mono, no bundled fonts), a dark display panel for what's playing,
segmented progress bars (ads in amber), chunky keys that press down, status
lights. Tokens in `App/Theme.swift`; shared pieces in `App/Deck.swift`.
Function matters more than look to Paul.

## Constraints

- **iOS only.** Native app in Swift and SwiftUI.
- **No Mac.** Paul has no Mac to build on. All
  building happens in the cloud: GitHub Actions (macOS runners) builds the app
  and uploads it to TestFlight. See `docs/SETUP.md`.
- **No server and no running costs.** All AI features run on the iPhone.
  Nothing calls Claude or any paid API at runtime.
- **Warn about money up front** (Paul, 4 Nov 2026): if anything in any
  project will or might charge Paul (services, plans, usage over a free
  allowance, store fees), say so before doing it or when speccing it.
- Paul is not a developer. Explain changes in plain English, keep the build
  green, and tell him when a new TestFlight build is ready to try.
- **Keep CLAUDE.md updated as you go** (Paul, 4 Nov 2026): record
  decisions, progress and open questions in the same change, without
  asking first, and mention briefly what changed here in your reply.

## Features (decided)

### Up Next queue
- Manual queue with drag to reorder, plus "Play next" and "Play last" on any episode.
- **Auto-add per show**: each subscribed show is set to **Off**, **Top** or **Bottom**.
  Newly followed shows default to **Bottom** (Paul's call).
- **Following a show**: only the newest episode downloads; older episodes
  are **not** marked played automatically (Paul's call). Instead, show
  pages have **Select** → Select All → Mark as played / unplayed, plus
  Mark all as played (menu), "Mark this and older as played", swipe to mark
  played, and an Unplayed / All filter. The follow sheet offers "Mark
  older episodes as played" as a one-tap option.
- **Show pages before following**: tapping a show in Discover, search or
  Add a show opens its page (artwork, description, Follow, latest
  episodes with notes on tap; "Open show" once followed). Episodes can't
  be played until the show is followed.
- **Show page**: FOLLOWING (tap to unfollow) and a settings key (showing
  Off/Top/Bottom) sit under the show's title and tags. Tapping an episode
  shows its keys, not its full notes: Play/Resume, Play next, Play last on
  one row; Download, TX (transcribe), Played and NOTES (opens the episode
  page) on the next. Tap again to close. Search box for the show's
  episodes (titles and notes).
- **Per-show settings** (show settings sheet): speed for this show (else
  the global speed; the player's SPEED key then says SHOW and changes the
  show's speed), skip intro / skip outro (seconds), keep downloads (All /
  Latest 1–10).
- **Undo**: Played, Remove from Up Next, Mark all / this-and-older /
  selected as played show an Undo bar above the mini player for 6 seconds.
- **Library**: HISTORY (everything played, newest first) and STATS (this
  week / 30 days / all time, last 7 days bars, top shows) keys; Continue
  listening (started, unfinished) above New Episodes.
- **Storage** (Shows screen): downloads per show with size, delete per
  show or all, and the per-show keep-latest limit.
- **Sleep timer extras**: sound fades out over the last 10 seconds; shake
  the phone or choose "5 more minutes" to extend.
- **Siri / Shortcuts / Action button**: Play Up Next, Pause, Play or
  Pause, Skip forward/back, Set sleep timer (App Intents).
- **CarPlay** (Paul listens in the car): Up Next and Shows tabs, standard
  Now Playing with a speed button and Up Next. Needs Apple's CarPlay audio
  entitlement: Paul applied (Audio) on 4 Nov 2026 and is waiting for
  Apple's email; then add it to the entitlements file (docs/SETUP.md).
- **Decided against (Paul, 4 Nov 2026)**: bookmark from AirPods, episode
  summaries, video podcasts, video clip cards (stay as they are, no new
  work), Apple Watch (maybe later if others ask), speaker separation
  (removed: battery not worth it; publisher transcripts still name
  speakers). Later: smart lists, folders, extra Podcasting 2.0 tags.
  Off-phone transcription: not now (Groq-type services are pennies a
  month if ever wanted).
- **Next (needs Paul's one-off setup)**: real-time new-episode alerts
  (free: GitHub Actions on a timer + CloudKit public database push), and
  Home/Lock Screen widgets + Control Centre button (needs an App Group).
- Add a show accepts Apple Podcasts links (Apple Podcasts can't export a
  subscription list, so there is no OPML import from it).
- **Import & export** (Shows screen): import an OPML file from another
  podcast app (Pocket Casts, Overcast, Castro…); imported shows start on
  Bottom, nothing downloads, already-followed shows are skipped. Export
  all followed shows as an OPML file through the share sheet.
- **Right after following a show, a settings sheet opens**: auto-add
  (Off/Top/Bottom), auto-download, notifications; the **last** item links to
  the separate "Top show priority" screen (ranking lives there, not in the
  sheet). The same sheet opens from the show page. The sliders icon on
  Up Next opens the "Shows" screen: Top show priority, "Keep each show in
  order", and download settings (Wi-Fi only, keep played downloads 24 hours).
- **Each show always stays in chronological order (oldest first).** This is the core rule.
  - **Top shows are ranked by priority** (Paul drags them into order on the
    Shows screen). The top of Up Next holds Top-show episodes in that rank order.
  - A new episode from a **Top** show goes **directly after the last queued
    episode of that show** if it has any; otherwise it goes **above every
    episode from lower-ranked Top shows** and below those from higher-ranked
    ones. So Paul's favourite show is always first, whenever its episodes arrive.
  - Re-ranking shows re-sorts the Top-show block of the queue (each show still
    oldest first). Manually placed episodes (Play next/Play last) keep their place.
  - A new episode from a **Bottom** show goes to the end of the queue, and is
    likewise never placed before an older queued episode of the same show.
  - If a show's older episodes sit further down the queue (e.g. added
    manually), the new one still goes after them, so listening order never breaks.
  - **Play next / Play last** follow the same rule when the setting
    "Keep each show in order" is on (default on).
  - Adding several episodes at once inserts them oldest first.
- **Auto-download**: new episodes from auto-add shows download automatically
  (respecting the Wi-Fi-only setting) so they are ready to play and transcribe.
- **Removal on completion**: when an episode finishes it is marked played,
  removed from Up Next, and its download is deleted to save space.
  Decided: delete straight away by default, with a setting "Keep played
  downloads for 24 hours" (off by default). Still proposed: episodes with
  bookmarks or clips keep their transcript but not the audio.
- "Keep playing new episodes" toggle (default on, at the bottom of Up Next):
  when the queue runs out, continue with the last week's unplayed episodes
  from auto-add shows, in the order the queue rules would put them.
- Queue rows show transcript status (ready / transcribing / waiting) and source
  (Auto · Top, Auto · Bottom, Added by you).

### Player
- Episode artwork (falls back to show artwork), chapter title, scrubber with ad
  breaks marked.
- **Skip back / forward buttons** in both the full player and the mini
  ("now playing") bar. Default **10 seconds** each way; back and forward are
  set separately (5, 10, 15, 30 or 60s) in settings, and touch-and-hold a skip
  button to change it on the spot. Lock screen and headphone controls use the
  same lengths.
- **Player is a tape deck** (replaces the artwork-coloured player, Paul's
  call with the Tape Deck look): artwork tile and title, a dark display
  with a big counter and a segmented progress bar (drag to scrub, ads in
  amber), transport keys, a SKIP AD key during ads, SPEED / TRIM / BOOST /
  SLEEP keys with lights, Transcript / Chapters / AirPlay keys. Library's
  New Episodes cards keep the show's colour on a cassette-style label strip.
- **Choose where to play**: an AirPlay/route button in the player opens the
  system device picker (AirPods, speakers, TVs, car) via AVRoutePickerView; the
  player shows "Playing on …" when not on the phone.
- Variable speed (1.0–2.0×), **Trim silences** (Overcast-style Smart Speed),
  **Boost voices**, sleep timer.
  - Built as: speed remembered globally; Trim and Boost are global switches,
    off by default (not per show); sleep timer 5/15/30/45/60 minutes or end
    of episode. Skip lengths are set on the Shows screen ("Skip buttons") or
    by touching and holding a skip button.

### Library and new episode cards
- Library tab opens with a **New Episodes** carousel of large cards like Apple
  Podcasts, styled as cassettes: episode artwork on top, a label strip in
  the artwork's colour with the show and "4H AGO", title, one-line
  description, a play key showing the time left, a download button and a
  more menu. Below: "Your shows" grid.

### Transcripts (on device)
- Use the publisher's transcript when the feed provides one
  (`<podcast:transcript>`), otherwise **transcribe on the iPhone**.
- Transcripts are a nice-to-have (Paul): default **Only when I ask** (a
  Transcribe now button); **Automatically while charging** is off unless
  Paul picks it; **As soon as downloaded** also available. **Transcribe now** (in
  the transcript screen, episode menus, Up Next menu; "Transcribe Up Next
  now" in settings) skips the schedule and downloads the episode first if
  needed. Transcripts are made only from downloaded audio and kept after
  the episode is played (for search and bookmarks).
- **Speakers**: identify who is speaking (on-device speaker separation with
  the open-source FluidAudio library, Apache 2.0; its ~30 MB of models
  download once, free) and label each line "Speaker 1", "Speaker 2"…
  ("Label speakers" setting, default on) Use real names when the publisher's transcript has them; Paul
  can tap "Name speakers" to rename, and names stick for that show.
- **Layout**: lines grouped under a timestamp every ~20 seconds or at each pause,
  e.g. `1m 20s` then `Speaker 1 — Hi` / `Speaker 2 — Hi too`.
- **Music**: detect music on-device (Apple's SoundAnalysis built-in sound
  classifier includes music) and show a music-note row with its time and
  length, e.g. "Music · intro theme · 14s". Ad breaks show as a dashed band.
- Transcript view follows playback; tap any line to jump there; select a line
  to share a clip, copy the quote or bookmark it.
- Search across all transcripts (and show titles, and saved clips).

### Clip sharing
- Quote card with the line, show, episode and timestamp; adjustable length
  (5–30s); options to include audio, link to the moment, or make a captioned
  video card.

### Ad skipping
- Detect ad breaks from the transcript (sponsor-read language, promo codes,
  "brought to you by", plus audio boundary cues). Dynamically inserted ads
  differ per download, so detection runs on Paul's own downloaded file.
- **Like Spotify: a Skip ad button** shows while an ad plays (full and mini
  player) and jumps to where the show resumes; skipping automatically is
  an option, off by default. Breaks marked on the scrubber and in the
  transcript; **Play ad** and **Not an ad** to correct.
- **Find ads while listening** (default on): no full transcript needed.
  While a downloaded episode plays, the next ~4 minutes are transcribed on
  the iPhone in 150s slices just to find sponsor reads (`AdScanPlan`).

### Chapters
- Use chapters supplied by the show (`<podcast:chapters>` JSON, or chapters
  embedded in the audio), including chapter artwork.
- When a show has none, **auto-generate chapters on the iPhone** from the
  transcript. Paul can switch between "From the show" and "Auto-generated".

### New episodes and notifications
- Pull to refresh on Up Next, plus a background check every 1, 3 or 6 hours
  (default 3). iOS decides the exact moment; **a delay is fine** (Paul's call).
- Per-show notification bell. The alert says where the episode went, e.g.
  "New from Tidewater Weekly, added to the top of Up Next".
- Option: download on Wi-Fi only.

### iCloud sync and backup
- Decided (Paul): shows and their settings, Up Next, played/progress, ad
  breaks and corrections, auto chapters, bookmarks/clips and settings sync
  to Paul's own iCloud (SwiftData + CloudKit private database; settings via
  iCloud key-value storage), so a reinstall or new iPhone gets them back.
  Downloads and transcript files stay on the phone (they're in the
  iPhone's iCloud Backup); unplayed downloads come back by themselves.
  Made for one iPhone at a time; duplicates from a sync are merged.
- Everything is also in the iPhone's normal iCloud Backup (downloads
  excluded on purpose).

### Discover
- Search for new shows (people, topics) using Apple's free podcast directory.
- Browse by category; "Because you listen to…" suggestions from shows in
  the same categories as ones Paul follows; UK top charts with Follow buttons.

## Website

- Showcase page: `website/poddeck.html`, published as a private claude.ai
  page (https://claude.ai/artifact/AQnieLZr5m9vCoNU9GoWpn); republish from
  that file to keep the same link. Only Paul can open it until he shares it.
- Same look as the app; feature sections with phone mock-ups, a live Up
  Next demo using the app's ordering rules, privacy note, download section.
- The download button says "Coming soon to TestFlight" until
  `TESTFLIGHT_URL` (top of the page's script) is set to the TestFlight
  public invite link.
- Show and episode names on the page are made-up examples (footer says so).
- Hosting it at its own address (e.g. GitHub Pages) is possible later;
  may need a paid GitHub plan because the repo is private.

## Proposed technical approach (confirm with Paul before big changes)

- SwiftUI app, SwiftData for storage, AVFoundation / AVAudioEngine for playback
  and audio processing (silence trimming, voice boost).
- Feed parsing: RSS 2.0 + iTunes tags + Podcasting 2.0 tags (transcript, chapters).
- Directory and search: iTunes Search API; charts from Apple's public RSS charts.
- On-device speech-to-text: Apple's Speech framework (check current APIs at
  build time), with an open-source Whisper model (e.g. WhisperKit) as an
  alternative if accuracy or language support needs it.
- Chapter titles and ad detection: rule-based on the transcript first; consider
  Apple's on-device language model framework if available on Paul's iPhone.
- Background refresh with BGTaskScheduler; local notifications only.
- Target device: Paul's iPhone 17 Pro on iOS 27.2. Minimum iOS: 26.0 for
  now (build machines only have the iOS 26 SDK; see Progress). Check Apple's current docs for iOS 27 speech, audio and
  on-device model APIs rather than relying on older knowledge.

## Build order (suggested)

1. Project skeleton, CI build, first TestFlight build (empty app).
2. Subscriptions, feed refresh, episode list, basic playback.
3. Up Next queue with the auto-add ordering rule (with unit tests for the rule).
4. Player controls, speed, trim silences, chapters from feeds.
5. On-device transcripts, transcript view, search.
6. Ad detection and skipping; auto-generated chapters.
7. Notifications, background checks, Discover, clip sharing.

## Progress

- Done (step 1, minus TestFlight): Up Next ordering rules in
  `Packages/PodcastCore` (`QueueEngine`) with unit tests; SwiftUI app
  (`App/`, project generated from `project.yml` by XcodeGen); GitHub Actions
  `Build` workflow (tests + unsigned simulator build). It runs on PRs; for
  other branches, start it by hand ("Run workflow").
- Done (step 2): feed reader (RSS + iTunes + Podcasting 2.0 transcript and
  chapter links), new-episode detection that never floods Up Next with
  back-filled episodes, Apple directory search, all unit-tested in
  PodcastCore. App: SwiftData library (shows, episodes, saved Up Next);
  "Add a show" (search by name or paste a feed link) followed by the show
  settings sheet; Library (New Episodes cards + Your shows grid); show page
  with episode list, Play next / Play last / mark played; refresh on launch
  (at most hourly) and pull to refresh, feeding Up Next by the rules; Top
  show priority screen (drag to re-rank, re-sorts Up Next; "Keep each show
  in order" toggle); streaming playback with mini player, basic full player,
  lock screen / headphone controls, resume position, mark played and
  auto-advance on finish, AirPlay device picker.
- Done (downloads and the rest of step 3): background downloads that carry
  on while the app is closed; auto-download of new episodes from auto-add
  shows (per-show toggle, Wi-Fi only setting, manual downloads go straight
  away); plays the downloaded copy when there is one; download deleted when
  played (or after 24 hours if that setting is on) and on unfollow;
  download buttons/status in Library, Up Next and show pages; "Keep playing
  new episodes". The per-show notification toggle is saved but does
  nothing until step 7.
- Done (step 1, TestFlight, 4 Nov 2026): Paul's Apple account, App ID,
  iCloud container, app record and GitHub secrets are set up. The
  TestFlight workflow (`.github/workflows/testflight.yml`) uploads on every
  merge to main; signing uses a distribution certificate and App Store
  profile issued per run through the API (`scripts/asc_signing.py`).
  Build 3 was rejected (error 90129: bundle name "Podcasts" is Apple's own
  app), so the bundle name is now Poddeck (`PRODUCT_NAME`; the Swift module
  keeps `PRODUCT_MODULE_NAME: Podcasts`). Build 6 was the first accepted
  build (valid, in internal testing); internal group "Me" has Paul, with
  access to all builds. Each run revokes all but the newest older
  distribution certificate, so Apple emails Paul "certificate revoked"
  after builds: expected, not a problem. Check uploads, TestFlight states,
  testers and certificates any time: run the TestFlight workflow with
  "status_only" (`scripts/asc_status.py`). The status step has a 4-minute
  limit and can't fail the run (it once hung after a good upload). Next: the one-off CloudKit
  schema deploy.
- Done (first iPhone feedback, 4 Nov 2026; it runs on Paul's phone):
  no now-playing panel on Up Next (the mini player covers it); empty Up
  Next message is a row (the overlay overlapped the toggle); DL / TX
  lights (`EpisodeLights`: downloaded or %, transcript ready or
  transcribing) on Up Next, show pages, Library cards and the player
  display; episode notes under the player keys and "Episode notes" in
  episode menus (`EpisodeNotesView`); transcript sync past inserted ads
  (`TranscriptAlign` in PodcastCore, tested): anchors from the words heard
  by find-ads-while-listening (downloaded episodes) and from on-device
  transcripts, stored per episode (`syncAnchors`), plus "This is playing
  now" on any transcript line for a manual fix.
- Done (second iPhone feedback, 4 Nov 2026): show preview pages
  (`ShowPreviewView`) from Discover / Add a show; show page settings key
  and expandable episodes (`EpisodeActions`); Mark all as played uses a
  centred alert; Library cards: inset label strip, card edge shadow only
  on the card shape (it outlined the artwork), play time on one line.
  Then: episodes open instantly (List row animation looked jerky); New
  Episodes cards smaller (220 wide) and tapping the artwork or title opens
  the episode page (`EpisodeNotesView`, now with the `EpisodeActions`
  keys); DL / TX lights never wrap and sit under the card's description.
  Then: episode and show notes keep the show's formatting
  (`PlainText.notesFromHTML`: paragraphs, line breaks, "• " lists, link
  addresses), refreshed for saved episodes on the next feed check; links
  and timestamps in notes are tappable (a timestamp plays from there); TX
  light shows "TX WAIT" while a transcript is queued (Transcribe now
  downloads first when the show has no transcript of its own).
  Then: show page has FOLLOWING (tap to unfollow) and SETTINGS keys side
  by side, and the Unplayed / All switch sits right under them (it was a
  list section header with a big gap); every confirmation is a centred
  alert with Cancel (no floating menus); Library spacing tightened.
- Done (third iPhone feedback, 4 Nov 2026): everything in the Features
  bullets above dated 4 Nov: keys under the show title, episode keys with
  NOTES, show search, per-show speed / intro / outro / keep downloads,
  Undo bar, history, continue listening, stats (`ListeningLog` model),
  storage screen, sleep fade and shake, App Intents, CarPlay scene
  (`App/CarPlay.swift`, scene in Config/Info.plist; inactive until the
  entitlement), FluidAudio removed. New model fields: Podcast
  speedOverride / skipIntro / skipOutro / downloadLimit, PodcastEpisode
  lastPlayedAt.
- Minimum iOS lowered to 26.0 (Paul's call to unblock TestFlight): the
  reliable build machine (macos-15-intel) has Xcode 26.3 / iOS 26.2 SDK
  only; every API used exists in iOS 26, and it runs on his iOS 27.2
  iPhone. Raise it again once GitHub's machines have the iOS 27 SDK.
- Done (step 4): speed, sleep timer, separate skip lengths (settings +
  touch and hold), artwork-coloured player and New Episodes cards (4.5:1
  text), "Playing on …", chapters (feed JSON or embedded in the audio, with
  chapter artwork, Chapters list, tap to jump), Trim silences (speeds
  through pauses over 0.3s) and Boost voices (compressor + limiter) via an
  audio tap. Trim/Boost strengths are first guesses: tune once Paul has
  listened. Ad breaks on the scrubber come with step 6.
- Done (step 5): publisher transcripts (best of JSON/VTT/SRT, with speaker
  names), on-device transcription with Apple's SpeechAnalyzer /
  SpeechTranscriber (checked against Apple's docs; iOS 26+ API), music
  rows via SoundAnalysis, transcript screen (timestamp groups, follows
  playback, tap to play, copy/share/bookmark, Name speakers per show),
  transcript status on Up Next rows, schedule + Transcribe now, Search tab
  (transcripts with highlighted quotes, shows/episodes, My clips =
  bookmarks for now). Not yet: speaker separation for on-device
  transcripts (see open questions); clip cards (step 7).
- Done (step 6): rule-based ad detection on on-device transcripts of
  Paul's download (sponsor phrases, promo codes, web addresses, "after the
  break", widened to bracketing music); shows with their own transcript
  still get an on-device pass (per the schedule) just for ads and music.
  Auto skip (setting "Skip ads automatically", default on), breaks marked
  on the scrubber, "Ad skipped at …" with Play ad / Not an ad (remembered),
  dashed ad band in the transcript. Auto-generated chapters (topic change
  by word overlap, ~8 min, ads as skipped "Sponsor break" chapters),
  titled by Apple's on-device language model (Foundation Models) when the
  iPhone supports it, word-based titles otherwise; Chapters screen switch
  From the show / Auto-generated. CI prints failing test lines at the end.
- Done (step 7): background feed checks (BGAppRefreshTask, Hourly / Every
  3 hours (default) / Every 6 hours on the Shows screen); per-show bell with
  local alerts saying where the episode went ("Added to the top of Up
  Next", "…at number 3", "…to the end"); Shows screen "All shows" list
  (bell + Off/Top/Bottom per show); Discover (directory search, category
  chips with category charts, "Because you listen to …", UK top charts,
  Follow buttons that open the show settings sheet); Share a clip from any
  transcript line (quote card in the artwork colour, 5–30s with −5/+5 and a
  waveform, include audio cut on the iPhone, link to the moment via the
  episode/show web page, video card as mp4; shared clips saved to My clips).
- All seven build steps are in place and the cloud build is green.
- Done (after Paul's answers): Podspot name and icon; follow = older
  played + newest downloaded; Unplayed/All filter and mark-all actions;
  Apple Podcasts links in Add a show; a fresh install follows Elis James
  and John Robins for testing (remove later); transcription default While
  charging; speaker labels on on-device transcripts (word timings from
  SpeechTranscriber matched to FluidAudio speaker turns).
- Done (second round of answers): Skip ad button + find ads while
  listening; transcription default Only when I ask; no automatic
  mark-as-played on follow, Select mode instead; new icon (option C, Paul's pick).
- Done (Tape Deck restyle): theme, key buttons, display panel, segment
  bar; Up Next (now-playing display + numbered tracks with TOP1/TOP2/BTM/
  YOU tags, times, download/transcript lights), mini player, player and
  transcript redesigned; then Library (cassette cards), Discover (category
  and Follow keys), Search, show pages and settings screens (key switches
  for Off/Top/Bottom etc., mono headings). Every screen is now Tape Deck.
  Showcase website restyled to match (same link).
- Done (iCloud sync + import/export): CloudKit-compatible models,
  `App/CloudSync.swift` (settings sync, merge duplicates, fix download and
  transcript records, reload Up Next), iCloud status on the Shows screen,
  `Config/Podcasts.entitlements`; OPML import/export (`PodcastCore/Feed/
  OPML.swift`, tested). iCloud only switches on in signed builds: needs the
  Apple account, then the one-off CloudKit steps in `docs/SETUP.md`.
- Done (rename): app, website and docs say Poddeck; cassette icon (D) is
  the app icon and the website's. The code project and bundle ID stay
  `Podcasts` / `com.gruffaluff.podcasts` (invisible to Paul).
- **GitHub Actions minutes (4 Nov 2026)**: the repo is private, so Mac
  build time comes out of the free monthly allowance (about 200 Mac
  minutes; Mac minutes count 10×). November used ~$19 of the $12 free
  compute and builds stopped ("not acquired by runner"); nothing was
  charged (GitHub Free, $0 due). **Decided (Paul): make the repo public**
  so Actions is free with no limit. The repo is public from 4 Nov 2026:
  never commit secrets (Apple keys live only in GitHub secrets).
  Build workflow runs on pull requests and by hand only. But GitHub kept
  blocking Mac jobs even after the repo went public (account Actions
  budget $0 "usage blocked"; lifting it needs a payment method, which
  Paul won't add). **Decided (Paul): use Codemagic** for Mac builds
  (free 500 Mac minutes a month, no card, stops at the limit):
  `codemagic.yaml` + `scripts/ci_testflight.sh`, uploads on every merge
  to main, build numbers 100+. GitHub's TestFlight workflow is manual
  only now. Setup steps in `docs/SETUP.md`. Plan (Paul agreed): only one
  service uploads automatically. After GitHub's reset on 1 Dec 2026, try
  one GitHub Mac build; if public-repo Mac builds run free, move the
  automatic uploads back to GitHub and keep Codemagic as the backup (and
  vice versa if not). Both use `scripts/ci_testflight.sh`-style steps.
  Codemagic works: build 102 (4 Nov 2026) uploaded and processing; the
  first Codemagic build caught a missing bracket that the blocked GitHub
  check never saw. Changes touching only docs, website, design or
  `.github` don't trigger a Codemagic build. To check what Apple has
  without a Mac: run the GitHub TestFlight workflow by hand with
  `status_only` and `runner=ubuntu-latest` (Linux runs free).
- CI: GitHub's Apple-silicon Macs are often unavailable ("job was not
  acquired by runner"), so Build and TestFlight now default to
  `macos-15-intel`; manual runs can still pick `macos-latest`.
- To check on the phone first: whether transcripts now stay in step
  (streamed episodes rely on "This is playing now"), Trim silences / Boost voices strength, ad
  detection accuracy (rule-based; tune phrases), auto-chapter quality,
  Apple chart feeds (could not be reached from the build machine; Discover
  falls back to directory search).

## Open questions for Paul

- None open. (Answered: name Poddeck + cassette icon D; earlier: Apple
  Podcasts has no export, links supported instead; speaker labels added
  now, can be removed.)
