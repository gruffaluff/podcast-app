# Podcast app — project brief

Read this first in every session. It records what Paul (the owner) has decided.
Keep it up to date when decisions change. Detailed look and screen specs are in
`notes/DESIGN.md`; the build and release pipeline is in `notes/SETUP.md`; the
original screen mockups are in `design/`.

## What this is

**Poddeck** (Paul's name, Nov 2026, to fit the Tape Deck look; it was
"Podspot", but "PodSpot: Find My Headphones" already exists on the App
Store and app names must be unique. If "Poddeck" turns out to be taken in
App Store Connect, register "Poddeck Player" and keep "Poddeck" on the home
screen. Icon (Paul, 5 Nov 2026): **middle-ground cassette "D"** (sand
shell, olive label, deep-olive reels), `design/icon/middle_D.png` from
`make_middle_icons.py`; also on the website. Other options looked at:
`middle_options.png` (A–D), `tape_options.png` (reel-to-reel E, big reel
F, tilted G, ink H), `mic_options.png` (reel-to-reel + microphone I–L),
may revisit. Before that: Tape Deck cassette D (`make_deck_icon.py`,
`deck_options.png`); Podspot icons `make_icon.py`, `options.png`). A personal iOS podcast app for Paul's own iPhone, delivered through TestFlight.
It combines the best parts of Apple Podcasts, Spotify, Pocket Casts and
Overcast. Goal: **minimal to look at, fully functional underneath**.

**Look: "Middle ground"** (Paul's pick, 5 Nov 2026; replaced Tape Deck,
which he loved but this won). Developed on the canvas
https://claude.ai/artifact/F5YT74YVLaxwJfGb56E42d (rows "Middle ground,
developed" and "Transcript, same height as artwork"). Warm sand page
(#E9E3D5), paper cards (#F6F2E9), ink text, one olive accent (#45543A);
big titles in Big Shoulders Display capitals (`Theme.big`), labels in
DM Mono (`Theme.mono`), body text in SF (fonts: Paul, 8 Nov 2026); what's
playing is shown in its artwork's colour (`ArtworkColors`) with the artwork
fading into it. Player: top area edge to edge with rounded bottom corners,
fixed height, ARTWORK / TRANSCRIPT switch (transcript = live lines + find),
ad breaks as a floating bar inside the top area (so nothing below moves),
then counter, wave progress bar, transport, SPEED / TRIM / BOOST / SLEEP
tiles, Up Next peek, notes. Mini player and show header are tinted from
the artwork too. Tokens keep their Tape Deck names in `App/Theme.swift`;
shared pieces in `App/Deck.swift`. Earlier explorations (Minimal, Flashy,
Abstract, Bold palettes, Olive) are on the same canvas. Function matters
more than look to Paul.
Also built (5 Nov 2026, second middle-ground build): Up Next's
now-playing header (`NowPlayingHeader`; the mini player is left off that
tab), Up Next pulled up over the player (`UpNextSheet`, from the player's
"Up next" row: reorder, swipe to remove, time at speed, Keep playing new
episodes), the episode page's status rows (`EpisodeStatusRows`: place in
Up Next, download, transcript, each with its key), and "New episodes go
to Nowhere / Top / Bottom" on the show page.

## Constraints

- **iOS only.** Native app in Swift and SwiftUI.
- **No Mac.** Paul has no Mac to build on. All
  building happens in the cloud: GitHub Actions (macOS runners) builds the app
  and uploads it to TestFlight. See `notes/SETUP.md`.
- **No server and no running costs.** All AI features run on the iPhone.
  Nothing calls Claude or any paid API at runtime.
- **Warn about money up front** (Paul, 4 Nov 2026): if anything in any
  project will or might charge Paul (services, plans, usage over a free
  allowance, store fees), say so before doing it or when speccing it.
- Paul is not a developer. Explain changes in plain English, keep the build
  green, and tell him when a new TestFlight build is ready to try.
- **"FNB" = for next build** (Paul, 5 Nov 2026): a message starting with
  "FNB" means add it to "Queued for the next app build" below and do not
  build, merge or start the work yet. Paul is compiling a list; build the
  list only when he says so. Reply briefly confirming what was queued.
- **"UBDM" = update but don't merge** (Paul, 6 Nov 2026): make the
  change on the branch (and open a PR so GitHub's free check compiles
  it), but don't merge, so no Codemagic build starts until Paul says
  "build".
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
- **Show page**: FOLLOWING (tap to unfollow), a settings key (showing
  Off/Top/Bottom) and a bell key (new-episode alerts on/off, lit when on;
  Paul wanted it on the page, not in a menu) sit under the show's title
  and tags. Tapping an episode
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
  entitlement: Paul applied (Audio) on 4 Nov 2026; Apple granted it
  5 Nov 2026 (goes into the next build, see the queue below).
- **Decided against (Paul, 4 Nov 2026)**: bookmark from AirPods, episode
  summaries, video podcasts, video clip cards (stay as they are, no new
  work), Apple Watch (maybe later if others ask), speaker separation
  (removed: battery not worth it; publisher transcripts still name
  speakers). Later: smart lists, folders, extra Podcasting 2.0 tags.
  Off-phone transcription: not now (Groq-type services are pennies a
  month if ever wanted).
- **Real-time new-episode alerts** (free; Paul approved 4 Nov 2026):
  `.github/workflows/alerts.yml` runs `scripts/new_episode_alerts.py`
  every ~15 min on GitHub's Linux machines. It reads the shows Paul
  follows from the "follows" record the app keeps in the CloudKit public
  database (`App/RealtimeAlerts.swift`), remembers what it has seen
  ("alert-state" record) and saves a PoddeckAlertEpisode (bell on:
  visible "New from …" alert) or PoddeckQuietEpisode (silent push that
  refreshes Up Next) record per new episode; the app subscribes to both.
  CloudKit server-to-server key ID (Production key, c74f…) is in alerts.yml
  (not secret; the Development key is a3fe…, same key pair); the
  private key is only in `.github/cloudkit-key.enc`, encrypted with the
  CLOUDKIT_PASSPHRASE secret Paul set (made by cloudkit-key.yml). Uses the Production CloudKit environment (TestFlight builds always do).
- **iCloud and alerts working (4 Nov 2026, build 112)**: Shows screen shows
  SYNC OK and "ALERTS OK · 2 shows, 2 with the bell sent · alerts on".
  How it got there (all needed again if the container is ever reset):
  TestFlight uses CloudKit Production, which can't create record types or
  new subscription fields. Record types come from
  `Config/CloudKitSchema.ckdb` (Codemagic "iCloud schema" workflow, needs
  CLOUDKIT_MANAGEMENT_TOKEN in the "apple" group, then Deploy in the
  Console). Query subscriptions must first exist in Development:
  `docs/cloudkit-subscribe.html` on GitHub Pages (CloudKit JS + a
  Development API token), then Deploy; its notification fields must match
  `RealtimeAlerts.subscribeIfNeeded` exactly (alert "New from %1$@: %2$@").
  CloudKit's modify calls report per-record refusals in their results, so
  always check them. Alerts job uses the Production server key (c74f…).
  GitHub's 15-minute schedule actually runs much less often; Paul is fine
  with that for now (a free outside timer such as cron-job.org could
  trigger it if ever wanted).
  Apple blips (11 Nov 2026): two runs in a row failed with "CloudKit
  records/lookup failed (400) UNKNOWN_CONTAINER: Invalid container to get
  container key" and the next ones worked with no change; nothing was
  missed (each run catches up on what the last one didn't do). The job now
  waits and tries again (20 s, 60 s, 120 s) on that kind of answer, 429 or
  5xx (safe: Apple did nothing), and on no answer at all for reads only (a
  repeated save could send an alert twice); it still fails if the trouble
  lasts past the retries.
  Known limits (told Paul 5 Nov 2026): GitHub turns off scheduled jobs in
  a repo with no commits for 60 days (it emails first; re-enable in the
  Actions tab, or any commit keeps it alive); the quiet "refresh Up
  Next" pushes are best-effort and iOS may drop or delay them (Low Power
  Mode, app force-quit); visible bell alerts are dependable once sent;
  timing is "within an hour or so", not instant. All free: public-repo
  Linux minutes, CloudKit public database and Apple's push service.
- **Subscriber (private) feeds** (Patreon, Supercast, Substack, Memberful,
  Acast+ etc.): pasting the private RSS link in Add a show works (the key
  is in the link). Feeds that need a username and password aren't
  supported yet. Privacy (4 Nov 2026): the follows record is sealed to the
  alerts job's key (P-256 ECDH + HKDF-SHA256 "poddeck-follows" + AES-GCM,
  `RealtimeAlerts.seal` / `followed_feeds`), because public-database
  records are readable by anyone using the app; the job's saved state and
  alert records hold only fingerprints of feed links and GUIDs; the job's
  logs (public repo) never print feed links or titles.
- **Widgets** (Paul set up the App Group `group.com.gruffaluff.podcasts`
  and App ID `com.gruffaluff.podcasts.widgets`, 4 Nov 2026): extension
  `Widgets/` (target PoddeckWidgets). Up Next widget (small: what's
  playing + play key; medium: + skip back / play / skip forward and the
  next episode; large: + next 4) and Lock Screen (circular play key with
  progress, rectangular, inline); a Control Centre / Lock Screen /
  Action button play-pause control. The app writes what they show to the
  shared folder (`App/WidgetSync.swift`, `Shared/WidgetShared.swift`,
  artwork copied small); the keys run in the app (audio intents). Signing
  makes a second profile ("Poddeck Widgets CI App Store").
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
- **Player (middle ground, Nov 2026)**: full screen. Top area in the
  artwork's colour: ⌄ close, device (AirPlay picker), find (transcript
  mode), notes (scrolls to the episode notes), mark played; ARTWORK /
  TRANSCRIPT switch with Full transcript and download keys; chapter chip;
  ad bar. Below: the progress line (T4: 10 pt, gaps at chapters, ads
  amber, no handle; played / ENDS / −left under it; touch and drag
  anywhere, it grows to 20 pt with a chapter + time bubble, slide down
  for half / quarter / fine), transport, SPEED / TRIM / BOOST / SLEEP tiles, Up Next card
  (opens the list), episode notes. Pull down past the top to close.
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
- Library tab opens with a **New Episodes** carousel of cards like Apple
  Podcasts': 248×330, the artwork across the top fading into its own
  colour, text below it ("22h ago", title, 3 lines of notes), white SHOW · 4H AGO, title, one line of description, a play
  pill with the time left, download and ⋯; it snaps card to card. Above it
  Continue listening; below "Your shows" (small cards with the description, and a sort key).

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
- **Speakers**: on-device speaker separation was removed (Paul: not worth
  the battery). Publishers' transcripts still name speakers; "Name
  speakers" renames them, and names stick for that show.
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
  (5–30s); options to include audio or link to the moment. (Video cards
  removed, Paul 5 Nov 2026: no interest in video for now.)

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
- Rebuilt 5 Nov 2026 (Paul: focus on features, how they work, and an
  experience you control with no subscription or hidden costs). Middle
  ground look. Sections: hero ("A podcast app you run, not rent"), a £0
  monthly "receipt", six features each with "How it works" steps and the
  settings you hold (Up Next with a live demo of the real queue rules,
  transcripts, ad skipping, player tools, new-episode alerts with honest
  timing, iCloud sync / OPML / widgets / CarPlay), "Where your data goes"
  table, first-open defaults, a "Fair questions" FAQ and download.
  Keep its claims in step with the app's defaults when they change.
- Ad skipping is not a selling point (Paul, 6 Nov 2026: not a strong
  feature). The site doesn't feature it: no ad section, no Skip ad in the
  hero phone (it shows the chapter chip), no ad line on the receipt; one
  small "Ad breaks · optional, off by default" card among the player
  tools. "0 ads" in the hero means the app itself shows no adverts.
- The download button says "Coming soon to TestFlight" until
  `TESTFLIGHT_URL` (top of the page's script) is set to the TestFlight
  public invite link.
- Real screenshots (Paul's iPhone, 6 Nov 2026, build 123) in
  `website/shots/` (600 px JPEGs; `scripts/build_site.py` copies them to
  `docs/shots/`; the claude.ai page gets them through the publish `files`
  map): the player is the hero, the transcript screenshot sits in the
  transcripts section, and "On a real iPhone" is a swipeable gallery (Up
  Next, Library, a show, chapters, show settings, Discover, stats). Up
  Next / show / Discover still show the old row style and circled skip
  keys: retake after the next build. Footer: screenshots show real shows,
  whose names and artwork belong to their owners; demo names are made up.
- **Hosting moved to Cloudflare Pages** (Paul, 6 Nov 2026): project
  "poddeck" (Workers & Pages), connected to this repo, production branch
  main, no build command, output folder `docs`; custom domains poddeck.uk
  and www.poddeck.uk (Cloudflare made its own records; proxied/orange is
  right now). Every merge to main redeploys it. GitHub Pages is switched
  off, so `docs/CNAME` and `docs/_config.yml` are leftovers (remove in a
  later build). Earlier GitHub Pages notes below are history.
- **Own address: poddeck.uk** (Paul bought it on Cloudflare Registrar,
  6 Nov 2026; the domain is his only cost, yearly). Cloudflare DNS records
  for GitHub must be "DNS only" (grey cloud), not proxied. Don't type the
  domain into GitHub's Pages settings by hand: that commits a CNAME file
  to main and starts a Codemagic build; `docs/CNAME` sets it on merge. Served free by GitHub Pages
  from `docs/` on main: `docs/index.html` is made from
  `website/poddeck.html` by `scripts/build_site.py` (adds the normal
  page head, favicon `docs/icon.png`, link-preview card); `docs/CNAME`
  holds poddeck.uk; `docs/_config.yml` keeps DESIGN.md / SETUP.md off the
  site. After editing the page: run the script, commit both, and
  republish the claude.ai page. DNS at the registrar: four A records for
  poddeck.uk → 185.199.108.153, 185.199.109.153, 185.199.110.153,
  185.199.111.153, and CNAME www → gruffaluff.github.io; then Settings →
  Pages: custom domain poddeck.uk, Enforce HTTPS once offered. Note: with
  a custom domain, gruffaluff.github.io/podcast-app/... redirects to
  poddeck.uk, so `docs/cloudkit-subscribe.html` (only needed if the
  CloudKit container is ever reset) would need poddeck.uk added as an
  allowed origin on its CloudKit API token. A merge to main also starts a
  Codemagic build, so website-only changes ride along with app builds.

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
  Apple Podcasts links in Add a show; (removed 5 Nov: a fresh install followed Elis James
  and John Robins for testing); transcription default While
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
  Apple account, then the one-off CloudKit steps in `notes/SETUP.md`.
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
  only now. Setup steps in `notes/SETUP.md`. Plan (Paul agreed): only one
  service uploads automatically. After GitHub's reset on 1 Dec 2026, try
  one GitHub Mac build; if public-repo Mac builds run free, move the
  automatic uploads back to GitHub and keep Codemagic as the backup (and
  vice versa if not). Both use `scripts/ci_testflight.sh`-style steps.
  Codemagic works: build 102 (4 Nov 2026) uploaded and processing; the
  first Codemagic build caught a missing bracket that the blocked GitHub
  check never saw. Merges didn't start builds at first: GitHub's webhook
  to Codemagic was missing (Codemagic's Webhooks tab showed no
  deliveries), not the "skip docs-only" filter we blamed and removed.
  Paul pressed "update webhook" on 4 Nov 2026 to recreate it; if merges
  stop building again, check that tab first. Every merge to main builds
  (manual builds: ▶, branch main, workflow TestFlight). Batch doc-only edits with app changes to save minutes. To check what Apple has
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

## Done in the Friday batch (5 Nov 2026, evening, build 121)

From the queue and the Notion notes after 18:10:
- New Episodes cards option E: 248×330 with a 12-point gap (Apple's
  proportions; Paul measured Apple Podcasts at ~247×330). Paul wants to
  live with it and be asked again next time he says to check Notion.
- Play next goes straight after the episode playing now (it was going
  above it, at the very top).
- Up Next: long press and drag to reorder any time; the reorder key
  (arrows icon, where Edit was) shows handles and delete buttons;
  settings moved to the right.
- Following a show: its latest episode goes into Up Next too (by the
  show's rule; new shows start on Bottom), as well as downloading.
- Find ads while listening is off by default (Paul: battery).
- Tab titles sit on the same line as the bar's buttons (`tabTitle`),
  so content starts higher, on Up Next, Library, Discover and Search.
- Discover tighter: smaller gaps around the category chips and section
  headers, smaller suggestion cards.
- Bedtime sleep timer off by default; CarPlay entitlement included.

## Done in the weekend build (6 Nov 2026)

From the Notion notes after 22:15 and this chat:
- Up Next episode actions (Paul picked A + C from the mock-up): tap a row
  to open a strip of icon keys with small labels under it (PLAY/PAUSE,
  NOTES, DL / % / DEL DL, TX / STOP TX, TO TOP, PLAYED, REMOVE; tap again
  to close); tapping the artwork plays; swipe right shows Notes (full
  swipe opens the episode page) and To top (= Play next); swipe left
  stays Played / Remove. `UpNextRowKeys` in UpNextView.swift.
- New Episodes card play pill shows "1h 16m" (plus "left" once started)
  on one line; the long clock (1:16:31) wrapped onto two lines.
- Show page keys (FOLLOWING, settings, bell) all a fixed 44 points high
  (they looked uneven; bigger text could stretch the first two).
- Also out with this build: the rebuilt website note and the alerts
  limits note above.

## Done in the Friday afternoon build (6 Nov 2026, PR #41, build 123; Paul: "let's build now")

From the Notion notes after 6 Nov 08:10:
- New Episodes cards: every layer pinned to 248×330 with overlays (the
  ZStack grew to its widest child, pushing the artwork sideways and
  leaving a strip of colour on one edge); the carousel uses
  `.contentMargins` so cards settle on the page margin, and
  `.scrollClipDisabled()` so the card shadow isn't cut off in a hard line
  (the "two tone" band under the cards).
- Up Next drag to reorder: the long-press menu on rows is gone (it fought
  the drag for the same press; the row keys cover everything it had), so
  a long press always picks the row up. Rows are separate paper cards with
  no system divider lines (lines tied to a row's place flickered while
  dragging), and the row no longer switches animation off (text jumped).
  Both ways of reordering (long press, and the reorder key's handles) were
  also hit and miss because every sync, including the one a reorder
  starts, reloaded Up Next about 2 seconds later and replaced the list
  with an identical copy, redrawing it mid-drag: `reloadQueueFromSaved`
  now changes nothing when the saved order matches. Row keys don't open
  while the reorder key is on.
- Ads (Paul: no Skip ad button seen; show suspected ads in the
  transcript): the player's transcript now marks lines in a suspected
  ad with an amber bar and "SUSPECTED AD" (`PlayerTranscript.swift`).
  Shows with their own transcript never had ads looked for unless the
  iPhone also transcribed them (Only when I ask + Find ads while
  listening off = never), so sponsor reads in the show's own transcript
  text are now found too (`TranscriptService.findAdsInText`: text only,
  no battery; times follow Paul's audio as far as the sync anchors allow;
  an on-device pass replaces them). Ads inserted into Paul's download
  aren't in the show's transcript, so only Find ads while listening or a
  transcript made on the iPhone catches those. Asked Paul where he saw
  the found ad with no button (scrubber / transcript / show).
- Player transport: previous / next chapter keys sit in the gaps either
  side of play when the episode has chapters (skip back, ⏮, play, ⏭,
  skip forward). Mini player: skip back, play, skip forward (its
  next-chapter key moved out; chapters live in the full player and the
  chapter list).
- Transcript sync (Paul: transcripts still not following along): the
  show's own transcript was only lined up with Paul's audio by Find ads
  while listening, which is now off by default, so after each inserted
  ad it drifted. New light "sync check" in `AdScanner` that runs whatever
  the ads setting: while a downloaded episode with the show's own
  transcript plays, a 25-second sample every 2½ minutes just ahead of
  the playhead is transcribed on the iPhone and matched to the
  transcript (sync anchors). Streamed episodes can't be checked (no file
  to sample): "This is playing now" on a transcript line is the fix there.
  Neither Find ads nor the sync check runs on an episode that already
  has a full on-device pass (`adsChecked`): it found the ads and lined
  the transcript up all the way through.
- Chapters list (Paul: tighter, like the pulled-up Up Next): opens at
  half height with a handle (drag up for full), inset paper rows with
  42-point artwork, one-line bold titles, "0:12:30 · 8m" underneath, the
  playing chapter highlighted with a NOW tag and the next one tagged
  NEXT; a summary line ("8 chapters", or "· made on your iPhone from the
  transcript") with the From the show / Auto switch above it.
- Website at poddeck.uk (files on the branch, see Website).

## Done in the last weekend build (6 Nov 2026, PR #42, build 124; Paul: "one last weekend build")

- Player skip back / forward have no circle round them and a
  bigger icon (36 pt) in proportion with the play key.
- One row style everywhere: **B, one rounded paper panel with thin
  lines between rows** (Paul, 6 Nov 2026, from the A/B mock-up). Shared
  `panelRow(index, of:, highlighted:)` in Deck.swift draws each row's
  slice of the panel and its own line (system separators run past the
  panel edge in plain lists). Used by Up Next (playing row highlighted),
  show episode lists, show previews and Discover (search and charts);
  the pulled-up Up Next and Chapters already looked like this. Search
  results still use plain rows (left for now). Branch only (UBDM).
- Stats "finished in 30 days" counts only episodes actually played
  (`lastPlayedAt` set); bulk Mark all as played made it say 1557.
- Reorder drag (Paul: white square corners on the lifted row, Shows
  screen): the Shows screen's lists were on the sand background, so iOS
  drew the lifted row on a plain light square. Its rows are now paper
  panels too (style B), and lifted rows keep rounded corners
  (`.contentShape(.dragPreview, …)`) in all three reorderable lists: Up
  Next, the pulled-up Up Next and Top show priority. Check on the phone.
- Website no longer tied to app builds (Paul, 6 Nov 2026, UBDM):
  `codemagic.yaml` skips the TestFlight build when a merge only touches
  `website/`, `docs/`, `design/`, `.md` notes, `.github/`,
  `scripts/build_site.py` or `scripts/new_episode_alerts.py`. Cloudflare
  still redeploys poddeck.uk on every merge to main. Takes effect from the
  merge that adds it (that merge itself builds). If a build that should
  have run is ever skipped, check the Codemagic build list for "skipped"
  and the changeset rule first.

## Done in build 125 (6 Nov 2026, PR #43; Paul: "let's build again")

- Up Next reorder reworked (Paul, build 124: "still janky", screenshot
  showed the lifted row clipped short with no handle and a gap left
  behind): Up Next now uses iOS's own inset grouped list (the panel,
  lines and lifted row are drawn by iOS, like the pulled-up Up Next and
  Shows screen) instead of hand-drawn `panelRow` slices; the
  `.contentShape(.dragPreview, …)` from build 124 was what clipped the
  lifted row and is gone from all three reorderable lists. `panelRow`
  (non-reorder lists) now uses the same 16 pt margins as inset grouped
  lists. If it's still not smooth, the next step is a hand-made reorder.
  UBDM.
- Up Next order snapping back after a drag (Paul's screen recording,
  build 124: drop a row, then a ghost copy and the old order comes back):
  `LibraryStore.commit` deleted and re-made every saved Up Next row on
  every change, so iCloud got a burst of deletes + new records and an
  older copy could come back and reorder Up Next. Rows are now updated in
  place (order / manual changed only when different; duplicates from old
  syncs removed). Covers the pulled-up Up Next in the player too (same
  `moveQueue` → `commit`). UBDM.
## Done in build 126 (9 Nov 2026, PR #44; Paul said "Build" on 6 Nov, but the GitHub suspension stopped the merge, so it went out with the batch below)

- Up Next reorder, after build 125 (Paul: main list "performing much
  better" but white corners on the lifted row; pulled-up Up Next "still
  janky": rows came back in the wrong order, once reversed, then snapped
  back). Both lists: each row paints its own colour edge to edge (no
  list insets) with a rounded drag shape, so the lifted row is the whole
  row with rounded corners. Pulled-up Up Next: no longer always in edit
  mode (that was the wrong-order redraw); long press and drag like the
  tab, swipe left to Remove (with Undo).

## Also in build 126 (9 Nov 2026, same PR #44; Paul: "GitHub is back. Push and merge and build"; on TestFlight 9 Nov, VALID)

- Made 7–9 Nov while the GitHub account was suspended (Paul: "sort with
  all the other fixes but don't push"); GitHub's Build check passed on
  the whole batch before the merge:
  - New Episodes card: "54m left" pushed the ⋯ off the card (fixed
    `.fixedSize()` pill); keys now fixed width and the pill can shrink.
    The card of the episode that's on shows a light pill with pause /
    "Playing" (or "Paused") and a moving wave; tap pauses / carries on.
    (Continue listening leaves out the episode that's on, so no change.)
  - Transcript "Waiting to transcribe" + Stop when nothing was asked:
    `TranscriptService.isQueued` no longer counts episodes that only sit
    in the line on Only when I ask; `prepare` marks "waiting" only when
    it will happen; `prepareUpNext` clears old wrong "waiting" (TX WAIT).
  - Scrubber: touch area 32x52 round the handle, starts after 6 points,
    moves by how far the finger travels (no jump to the finger). A jump of
    2 minutes or more offers "Jumped to 34:10 · UNDO" (back to where it was).
  - Refresh artwork in its own "Artwork" section on the Shows screen.
  - Storage: the footer note is a plain row on the sand (was a white block).
  - Clips: CLIP key on the line playing now in the player's transcript,
    Share clip on every line's long press; Search tab "My clips" is "Saved".
  - Player top area: the artwork fills the width from the top and fades
    into its colour (was a 300-point picture on the right with a radial
    fade; Paul's Tailenders screenshot was the player, not the show page).
  - Alerts (6, option A): the phone's own alerts have the show as the
    title, where-it-went as subtitle, episode as the message; iCloud-pushed
    ones read "Show · Episode" via `App/en.lproj/Localizable.strings`
    (the subscription's fixed key "New from %1$@: %2$@"). B (a
    notification service extension) later if wanted.
  - No internet: `NetworkStatus` (NWPathMonitor) and an "NO INTERNET ·
    DOWNLOADS STILL PLAY" bar above the mini player (`App/Welcome.swift`).
  - First-open welcome (`WelcomeView`): only when nothing is followed;
    Find shows (to Discover) or Look around first; shown once.
  - New Episodes cards like Apple Podcasts' (Paul's screenshot of
    Apple's card, 7 Nov): artwork across the full width at the top, shown
    almost whole and fading out by 186 points; below it "22h ago" (no show
    name: the art shows it), title on one line, up to 3 lines of notes,
    then a pill with just the time ("53m"), download and ⋯ softer. Card
    stays 248x330.
  - New Episodes (Paul, 8 Nov): after marking a lot played the carousel
    stayed scrolled past the cards left (empty strip until a swipe); it
    now remembers the card in view (`scrollPosition`) and goes back to the
    first when that card goes. Following a show filled the carousel with
    its back catalogue: cards are now episodes out since the show was
    followed (`followedAt`) plus each show's newest one (`newCards`).
  - New Episodes card: a mark-played key (✓ in a circle) beside download,
    with the Undo bar (Paul, 8 Nov).
  - History / Continue listening rows (`HistoryRow`): the show name on
    one line and "PLAYED · 3D AGO" / "12m LEFT · 1H AGO" on its own line
    under it (Paul, 9 Nov: lost after long show names).
  - Download keys stop the download while it runs (Paul, 9 Nov): the
    player's top-row key now does (it did nothing mid-download) with a
    stop square in the filling ring; the card's stop square is bigger.
    Up Next ("40%" key), show pages (STOP DL) and menus already did.
  - Transcript keys (Paul asked 9 Nov if they work like download): they
    already turn into stop keys while a transcript is on its way (Up Next
    row keys, show pages, menus, player panel); now they also show how far
    it has got ("TX 62%" on Up Next, "STOP TX · 62%" on show pages).
    Stopping doesn't cancel a download it started first (the file is kept).
  - Back catalogue (Paul, 9 Nov: follow a show and listen to all of it,
    e.g. 200+ episodes): "Add all to Up Next, oldest first" in the show
    page's ⋯ menu (with a confirm giving the count) and in the follow
    sheet's Older episodes section. `LibraryStore.addBackCatalogue`: every
    unplayed episode not already queued, via `QueueEngine.playLast` (end
    of Up Next; with Keep each show in order they sit before any newer
    episode of the show already queued). Undo bar. Nothing extra
    downloads. Only as many episodes as the show's feed lists.
  - "In Up Next · 2nd" on the episode page (and under the player) is a
    link (Paul, 9 Nov): it closes the page / player, switches to the Up
    Next tab, scrolls to the episode and opens its row keys
    (`LibraryStore.revealInUpNext`, watched by RootView and UpNextView).

## Done in build 127 (9 Nov 2026, PR #45; Paul: "address and build", recordings + Notion notes after 7 Nov 09:20; on TestFlight 9 Nov, VALID)

- Up Next (tab and pulled-up): rows banded (every other row `Theme.surfaceBand`)
  instead of divider lines; the `.contentShape(.dragPreview…)` is gone
  again: it made the lifted row a separate see-through copy with the
  row's text showing through (recordings); iOS's own lift is used.
- Up Next rows show when the episode came out ("9 NOV", or with the year)
  on the third line, before PLAYING / downloading.
- Player: the Undo bar floats over the page (overlay) instead of a
  safe-area inset, which resized the scroll area and flickered.
- Player: behind the titles the artwork is blurred and the colour fade is
  stronger, so the titles stay clear over busy artwork; the show name
  opens the show page. Episode page: artwork and show name open the show
  (`LibraryStore.revealShow`: RootView closes the player / page and
  switches to Library, LibraryView pushes the show on its path).
- New Episodes card: the playing card's pill shows the time left (not the
  squashed "Pla…"), with pause and the moving wave.
- Show page episode rows: olive dot for unplayed, a tick for played, and
  unplayed titles semibold (the fade alone wasn't clear).
- Show settings sheet: Older episodes are key buttons (MARK OLDER PLAYED,
  ADD ALL TO UP NEXT) and Add all shows every time, not only after
  following (it's also in the show page's ⋯ menu).

## Done in build 128 (9 Nov 2026, PR #46; Paul: "Build it", Notion after 9 Nov 17:40 + two recordings; on TestFlight 9 Nov, VALID)

- Undo bar flashing and vanishing (recording: a long scrubber jump showed
  "Jumped to · UNDO" for a tenth of a second): there is an Undo bar on
  every tab and in the player, and when one left the screen its 6-second
  wait was cancelled, which cleared the Undo at once (`try?` swallowed
  the cancel). Only a full 6 seconds clears it now (`UndoBar`).
- Player top keys: solid dark olive fill with a thin light edge
  (`NowPlayingView.keyFill`, also used by the show page keys and the
  player transcript keys); the blur behind the titles is gone.
- Up Next (tab and pulled-up) is now a plain full-width list: banded rows
  edge to edge, so the lifted row no longer keeps the rounded panel's
  corner mask (white corners), and the band colour is darker
  (`surfaceBand` #E2DAC7) so it doesn't get lost against the sand. The
  summary line is a plain first row (plain lists pin headers). iOS's own
  lifted row may still look slightly see-through: that's iOS; a
  hand-made reorder is the next step if it still bothers Paul.
- Show settings Older episodes: ordinary rows in the paper panel ("Mark
  older episodes as played", "Add all to Up Next, oldest first") with an
  icon, instead of the black and white keys.
- Follow from a show preview: the page now stays "✓ FOLLOWING · OPEN
  SHOW" after the settings sheet closes (`Follower.followed`; the sheet
  cleared `justFollowed`, and chart items have no feed link to look the
  show up by). Discover's Follow keys use the same.

## Done in build 129 (9 Nov 2026, PR #47; Paul: "Go for build"; on TestFlight 9 Nov, VALID)

- Tidy-up from the 9 Nov code review (no visible change; battery and
  smoothness): iCloud tidy-up only after changes come in (not after our
  own saves every 15 s while playing); transcript "is it there" checks no
  longer read whole files; Find ads / sync check keep the show's
  transcript for the episode and can't run two slices at once (a
  cancelled slice no longer clears the next one's handle); artwork memory
  capped at ~80 MB; artwork colours saved between launches, one shared
  drawing context; widget artwork copies no longer used are deleted;
  Trim silences checks 10×/s (was 20×); Up Next row colours and dates
  worked out once; the full player looks its episode up once per episode;
  show page "Add all" count only when asked; speaker names read once per
  redraw. Feeds: unchanged feeds are skipped by a fingerprint of their
  bytes (`LibraryStore.feedFingerprints`, this iPhone only), so their
  notes aren't re-tidied on every check. Dead code removed
  (`requestOpenPlayer`, `currentChapter`, `accentShadow`, `screenTitle`,
  `darkKey`, `panelRow(highlighted:)`, the "starterShowFollowed" sync key)
  and the AdScanner "default on" comment fixed. Not done (bigger, later if
  needed): splitting the player's clock into child views, caching the show
  page sort, counting unplayed without loading episodes.
- Website files: `docs/CNAME` and `docs/_config.yml` removed; DESIGN.md and
  SETUP.md moved to `notes/` (Cloudflare served them at poddeck.uk).
- Up Next banding by place among the rows that aren't playing
  (`Theme.upNextBand`), tab and pulled-up.
- Style rules (9, Paul 9 Nov 2026): choose one of 2–4 = `DeckSwitch`
  (Shows screen: check interval, skip lengths; was iOS segmented); choose
  from a list = `DeckPicker`, a sand key with ▾ (show settings: keep
  downloads, speed, skip intro/outro; Shows screen: after an episode,
  transcribe, keep downloads under; was olive drop-down text); do
  something = `DeckActionRow` / key buttons (Transcribe now, Refresh
  artwork, Stop all, the transcript screen's Transcribe now / Try again /
  Stop, clip −5/+5; was iOS round buttons or olive text); disabled keys
  dim (`KeyButtonStyle` reads isEnabled); olive no longer decoration
  (Discover top-3 ranks, welcome icons, clip error); can't be undone =
  red with a confirm (Storage "Delete these downloads" now asks; "Stop all
  transcribing" isn't red any more). Text: `Theme.text(size, weight)`
  follows the iPhone's text size like the labels; lists, player titles,
  chapters, transcripts and show pages use it; New Episodes cards, the
  mini player, share cards and icons in round keys stay fixed on purpose.
- Copy diagnostics (Paul, yes 9 Nov 2026): Shows screen → Problems →
  COPY puts a plain-text summary on the clipboard (`App/Diagnostics.swift`:
  app/iOS/device, counts, downloads, playing, settings, iCloud status; no
  feed links).

## Done in build 130 (9 Nov 2026, PR #48; Paul: "Go"; on TestFlight 9 Nov, VALID)

- **One row style: flat banded rows everywhere** (Paul, after build 129:
  "we are either all rounded boxes or not"). `panelRow` is now flat full-width rows
  alternating paper / band (`Theme.band`), 16 pt insets, no lines: show
  episode lists, show previews, Discover search and charts, Add a show
  results. Your shows "card" and "list" layouts and the Chapters list
  use the same bands (were separate rounded boxes / lines / an inset
  panel). The rounded-panel code (`PanelBackground`) is gone. Settings
  screens keep iOS's grouped sections. Search results still plain rows.
- Discover chart / search rows were squashed (Paul): no ">" arrow (the
  link sits invisibly behind the row), the 32 pt the panel margins took
  goes to the text, title in `Theme.text(15, .semibold)` (was .body, which
  grows without limit), + FOLLOW is a sand key so it shows on every band.

## Done in build 131 (9 Nov 2026, PR #49; Paul: "Build"; on TestFlight 9 Nov, VALID)

- **Cards, not bands** (Paul, after build 130: "I don't think I like
  banded, go back to the card style"). Every list row is its own rounded paper card (`Theme.surface`,
  radius `Theme.cardRadius` 14) on the sand with a 8 pt gap: `panelRow`
  (show pages, show previews, Discover, Add a show), Up Next tab and
  pulled-up (playing card in `Theme.highlight`, `Theme.upNextCard`),
  Chapters, Your shows card and list layouts. `deckCardRow()` gives the
  cell a sand background, so the row iOS lifts to drag has sand corners,
  not white ones. Side margins 12 pt + 12 pt inside the card. Bands
  (`surfaceBand`, `Theme.band`) removed.
  Card look: **B, paper cards with a soft shadow, the same everywhere**
  (Paul, 9 Nov 2026, from https://claude.ai/artifact/JhXRL117ui7WKLjVYFomYU;
  A flat paper and C outlined were the others). One modifier,
  `deckCard(fill, radius)` in Deck.swift (radius 14, two light shadows),
  used by every list row (`panelRow`, Up Next tab and pulled-up, Chapters,
  Your shows card / list, Continue listening, History, Storage, Search
  results, Up Next suggestions) and every card panel (player's Up Next
  card, episode notes box, episode status rows, Stats tiles). Cards sit
  10 pt apart. The ALL ▾ / LATEST ▾ keys inside cards are sand (style
  rule). Settings screens keep iOS's grouped sections.
- **Swipe keys all round** (Paul: two looks; prefers the round ones):
  every swipe action has an icon (Played ✓, Remove, Unplayed, Play next /
  Play last, Delete), so iOS draws them all as round icon keys with a
  label, like Notes / To top. Text-only ones drew as rounded squares.

- **Colour schemes** (Paul, 9 Nov 2026: "include all 4"; mock-up
  https://claude.ai/artifact/HkYMMBunqi9jCSsmn8hrae). Shows screen →
  Colours: SAND (default) / SLATE / CLAY / NIGHT (`DeckSwitch`), saved as
  "colourScheme" and synced with the other settings. `ColourScheme` in
  Theme.swift holds each palette; every `Theme` colour token is now
  computed from `ColourScheme.current`. `SchemedRoot` (PodcastsApp.swift)
  sets the current scheme before drawing, redraws the whole app when it
  changes (`.id`, so open sheets close) and sets iOS's light / dark look
  (Night is dark, so system controls, menus and the keyboard follow).
  Card shadows are black in every scheme (`Theme.shadowSoft/Wide`). The
  player, mini player and show headers keep the artwork's colour; widgets
  keep their own Sand colours. **Default is AUTO** (Paul: "Night should be
  the default for dark mode"): Sand when the iPhone is light, Night when
  it's dark (`ColourScheme.resolve`); picking a scheme fixes it. Keys:
  AUTO / SAND / SLATE / CLAY / NIGHT.
## Done in build 133 (10 Nov 2026, PR #50 + #51; Paul: "go"; 132 failed signing; on TestFlight 10 Nov, VALID)

- First try failed in Codemagic's signing step (Paul's log, 10 Nov):
  one App Store Connect read timed out after 60 s ("The read operation
  timed out" in `asc_signing.py` `make_profile`), nothing in the app.
  `asc_signing.call` now retries reads and deletes up to 4 times (5 / 10
  / 15 s apart) on a timeout or no connection, and any call on 429 / 5xx;
  a POST that times out isn't repeated (so no second certificate). The
  merge of that fix re-ran it as build 133.

- **Level bars: "B bold 2"** (Paul, 10 Nov 2026: more sensitive, vibrant,
  animated, fill the time area; mock-ups on
  https://claude.ai/artifact/4wc6MmmGPEK8Pko9MVGFdK, he picked B bold 2
  over A, B, C ripple, D, E meters and the A+B mixes). Thin bars across
  the whole time strip, behind the numbers: low pitches in the middle,
  high at the edges, nearly invisible at the edges and almost full
  artwork colour in the middle. Each bar follows its own pitch band
  (`App/BandMeter.swift`: 1024-point FFT with Accelerate on the audio tap,
  24 log-spaced bands 90 Hz–9 kHz, nothing allocated on the audio thread;
  `AudioTapState.bandLevels()`, `PlayerModel.outputBands`), jumps up at
  once and falls slowly, and levels itself to the episode's loudness
  (`LevelMeter` in NowPlayingView.swift: recent loudest band, 38 dB range,
  +1 dB per band tilt for speech). 60 fps while the full player is open
  and playing; resting bars when paused. The old single loudness reading
  (`AudioTapState.level`, `outputLevel`) is gone.
- **Your shows sort and layouts** (Paul, 10 Nov 2026): a sort key (⇅) on
  the strip beside the layout keys: A–Z, Z–A, latest episode newest /
  oldest first, date followed newest / oldest first (`ShowsSort`, saved
  as "showsSort", synced); the header reads "YOUR SHOWS · 12" with the
  sort on the right. "Description only" layout dropped (old setting falls
  back to the cards); the card + description rows now show TOP / BTM /
  OFF and "n NEW" like the large cards (`ShowBadges`).

## Done in build 134 (10 Nov 2026, PR #52; Paul: "build"; on TestFlight 10 Nov, Paul has it)

- **Progress bar: "2C"** (Paul, 10 Nov 2026: build 133's live sound bars
  and the loudness progress bar looked like the same thing twice). Mock-ups:
  https://claude.ai/artifact/S7TvbPMWVckktnvwGp9PEe (he picked 1: keep the
  live bars up top, a line for progress) then
  https://claude.ai/artifact/VGyopsCJswak8noEutK2pX (line styles; he picked
  2C). `ProgressPill` in NowPlayingView.swift: a 16 pt pill split at
  chapters (3 pt gaps), played part in the artwork's colour, ad breaks as
  amber stripes (bright played, pale ahead) with "AD" above, a 30 pt round
  handle (paper with an artwork-colour ring; same drag rules, 44×52 touch
  area), and "CH 3 · FAN CALLS" under it (follows the handle while
  dragging). The loudness waveform (`Waveform`, `SegmentBar`) is gone, so
  the downloaded file is no longer read to draw the bar.

## Done in build 135 (10 Nov 2026, PR #53; Paul: "Build")

- **Player time / progress: "A3+"** (Paul, 10 Nov 2026, after build 134:
  handle sat below the pill and he wasn't sure about the look; mock-ups
  on https://claude.ai/artifact/HGkM8MpcadQwMbk7C2vJkN: Now, A–E, thinner
  lines, A1–A3, then A3+ and seven ideas M1–M7 for the space between the
  times; he liked A3+ and kept the chapter there: "let's stick with how
  we are", then "Stick with m1"). The live sound bars ARE
  the progress line (`LiveScrubber` in NowPlayingView.swift, replacing
  `ProgressPill` and the separate `LevelBars`): 56 bars, played in the
  artwork's colour, ahead pale, ad bars amber under a bracket with an AD
  tag; dashed line + numbered dot (filled once reached, the current one
  ringed; dots that would overlap are left out) at each chapter; ink
  playhead line with a 24 pt round handle in its middle. Bars near the
  playhead follow the low pitches, further ones the high, from
  `BandMeter` / `LevelMeter` as before (60 fps only while the full player
  is open and playing). Time row: played left, "CHAPTER 2 OF 5" + the
  chapter's name in the middle, −left and ENDS right. Handle fix: the
  touch area is placed by its centre (`.position`), so it sits on the
  line. Check on the phone: long chapter names, many chapters, colours on
  light artwork.

## Done in build 136 (10 Nov 2026, PR #54; Paul: "Build")

- **Player closed after switching apps** (Paul, build 135: open the
  player, swipe to another app, come back: it had shrunk to the mini
  player). Cause: on the AUTO colour setting, iOS briefly draws the app
  in both light and dark for the app switcher; that counted as a scheme
  change, and the whole app was redrawn from scratch (`.id(chosen)`),
  closing the player. `SchemedRoot`
  follows the iPhone's light / dark only while the app is in use, and
  keeps "player open" and the tab itself (`RootView` takes them as
  bindings), so even a real scheme change keeps the player open.
- **Progress line, Apple style: "T4 firm"** (Paul, 10 Nov 2026, after
  build 135: "not sure", sent a recording of Apple Podcasts' scrubber;
  mock-ups https://claude.ai/artifact/NUUfPjhX55n9SXWRFxMAAH, he picked
  T4 of T1 3→10, T2 5→14, T3 7→16 (Apple's, measured from his recording),
  T4 10→20, T5 14→24). `ScrubLine` in
  NowPlayingView.swift (replaces `LiveScrubber`, the time row and the
  chapter between the times): a 10 pt line right under the artwork area,
  split by 3 pt gaps at chapters, played in the artwork's colour, ads
  amber (pale ahead); no handle. Under it: played and −left (16 pt DM
  Mono) at the ends, "ENDS 22:35" in the middle. Touch anywhere and drag
  (moves by how far the finger travels, so a touch never jumps): it grows
  to 20 pt and 8 pt wider each side, a paper bubble above the finger
  (over the artwork area's edge) shows the chapter name and time, and the
  middle text shows the speed; sliding down slows it
  (`PlayerOptions.scrubSpeed(below:)`, tested: <40 pt normal, 40–90 half,
  90–140 quarter, further an eighth). Jumps of 2 min+ still offer Undo.
  No live sound bars any more: `BandMeter` and the tap's band analysis
  are gone (less work on the audio thread). Paul's build 135 screenshot
  also showed chapter dots 1 and 4 on top of each other: gone with this.
- **Player transcript** (Paul, 10 Nov 2026, build 135 screenshot: lines
  cut to one line with "…"; wants whole lines, the line now bigger and
  clearer, the others smaller and faded, and a smooth scroll instead of
  jumping). the panel is a scrolling list of
  every line (`PlayerTranscriptPanel.window`, LazyVStack) that glides
  (0.6 s ease) to keep the line now a third of the way down; whole lines
  (`fixedSize`; the fixed-height panel had squeezed them to one line);
  line now 23 pt bold, others 15 pt, heard lines 38% and coming ones 55%;
  edges fade out. Scrolling by hand pauses following until 6 s after you
  let go, or BACK TO NOW. CLIP key sits level with the time label.
- **Rewind when you resume** (Paul, 10 Nov 2026: "smart rewind like other
  apps"): after a pause the player goes back 3 s
  (pause of 5 s–1 min), 10 s (1 min–1 h) or 20 s (over an hour); none
  after a quick tap, and only if nothing moved the playhead while paused
  (`PlayerModel.rewind(afterPause:)`, `pausedAt`). Covers the play key,
  lock screen, headphones and resuming after a call. Setting "Rewind a
  little when you resume" (Shows screen → Skip buttons, on by default,
  synced as "rewindOnResume"). Also seen in his build 135
  screenshot: chapter dots 1 and 4 overlapped (short first chapters),
  gone with this design.

## Queued for the next app build

- **New Episodes ideas** (Paul, 11 Nov 2026: fresh ideas for the Library's
  New Episodes). Mock-ups https://claude.ai/artifact/GR7UfPFs12b4Mpt8oZ1TyC
  next to today's carousel: 1 Inbox (Today / Yesterday / This week rows,
  swipe right Up Next, left played, "All caught up"), 2 Show circles like
  Stories (ringed show icons with counts, tap for that show's new ones),
  3 Triage deck (one big card, swipe right Up Next / left played / up
  play now), 4 Tape shelf (episodes as cassette spines in show colours,
  tap one to slide it out), 5 Morning digest (one front-page card, "6
  new since yesterday", one line each, Add the rest to Up Next). Waiting
  on Paul.
- **Your shows sort menu** (Paul, build 136 screenshot: "Newest first" /
  "Oldest first" twice, no way to tell which sort they were). Inside a
  Picker, iOS dropped the section headings. Now three menu sections
  (Name / Latest episode / When you followed) of plain buttons with a
  tick, each saying what it sorts by: "Name, A to Z", "Newest episode
  first", "Recently followed first", "Followed longest ago first" etc.
  (`LibraryView.sortOption`). Also the header (Paul: "what's the ·…"):
  the sort name beside the count squeezed "YOUR SHOWS · 12" down to
  "YOUR SHOWS ·…"; now the count always shows and "SORTED BY NEWEST
  EPISODE" sits on a small line under it (`yourShowsTitle`; A–Z / Z–A
  read "NAME A–Z"). Large artwork tiles dropped (Paul, 11 Nov 2026: "just
  have the card and desc view"): Your shows is always the small cards
  with the description, the layout keys and `ShowTile` are gone, the strip
  holds only the sort key, and "showsLayout" no longer syncs. On the
  branch, not built.
- **Player layout ideas** (Paul, 10 Nov 2026, after build 136: "we're in
  a good spot", but curious if another layout is better). Mock-ups
  https://claude.ai/artifact/KrYT3het2R5buAj5JzCBzP next to build 136:
  1 Tidy (fewer top keys, tiles as a slim icon row, Up Next as one line);
  2 Artwork first (square artwork card on a washed page, titles under,
  tap artwork for transcript, bottom icon bar); 3 Reader (transcript fills
  the screen, compact control dock that pulls up); 4 Deck (cassette:
  turning reels, LCD with chapter and times, latching keys); 5 Gestures
  (full-bleed artwork, tap to pause, double tap sides to skip, chapter
  cards, everything else in a pull-up drawer). Paul: none improve on
  136. Round 2, https://claude.ai/artifact/LaxiGxbUhYrBwvFQHdMrQZ: 6 Pages
  (fixed controls below, swipe the top between Art / Chapters / Text /
  Next), 7 Timeline (chapters as stops down the screen, the current one
  opens with the controls), 8 Dial (progress as a ring round play, drag
  round to scrub), 9 Dashboard (tiles: said just now, chapter left, up
  next, time saved, sleep), 10 Poster (no picture: artwork colour, huge
  time and title in Big Shoulders). Paul liked 8 (Dial) and 10 (Poster).
  Round 3, https://claude.ai/artifact/LAGJTUdpda11cHuwEJ6LrL: new 11
  Moving tape (fixed playhead, loudness strip slides under it, pinch to
  zoom), 12 Chapter cards (stack, flick to the next chapter), 13
  Conversation (transcript as chat bubbles, controls where you'd type);
  then 8 across the app (8a ring round the artwork with chapter ticks,
  8b scrubbing round the ring, slide inward for finer, 8c progress rings
  on Up Next rows and round the mini player's play key) and 10 across
  the app (10a refined poster player, 10b transcript as big lyric type,
  10c Library New Episodes as colour posters, poster mini player).
  Then (Paul: "flesh out poster with screens of each page", with the
  Inbox and Up Next): https://claude.ai/artifact/KbVas33x1ccwvAFM9YoccR,
  every screen in the poster look: Up Next (playing episode as a colour
  block, rows with a show-colour strip and big Big Shoulders titles),
  Library with the Inbox (Today / Yesterday rows, swipe for Up Next /
  played, Your shows as colour tiles), player, transcript as lyric
  sheet, show page and episode page as colour posters, Discover (chips,
  "because you listen to" tiles, chart rows), Search (shows, episodes,
  quotes), Shows settings (plain, Top priority as colour rows), poster
  mini player strip. Waiting on Paul.
- 7 time row: left as it is (Paul, 9 Nov 2026).
- Not now (Paul, 9 Nov 2026): "Save for later" list, sleep timer "end of
  chapter". Dragging in Up Next is OK as of build 128: no hand-made
  reorder.
- **Still waiting on Paul**: where he tried Undo
  and saw nothing; whether to move alerts to Cloudflare (free cron
  Worker) as a backup to GitHub; other iPhone sizes not checked yet.
  Feeds with a username and password: later.
- Type (Paul asked 8 Nov "do we have a consistent font?"): one family,
  Apple's system font (SF) everywhere, in three roles: `Theme.big`
  (heavy condensed titles), `Theme.mono` (small spaced capitals; despite
  the name not monospaced) and plain text. Sizes are set three ways:
  Theme helpers (~106 places), fixed `.system(size:)` (~50, don't follow
  the iPhone's text size) and iOS text styles (~46). Proposed with the
  style rules (9): one small type scale in Theme and every text through
  it, so sizes match and all follow the text size setting.
  Font options for titles and labels (body text stays SF) on
  https://claude.ai/artifact/P61T5FHNMwcgxsDNrzmgWM: A today, B New York
  + SF Mono (built in), C Big Shoulders + DM Mono (my pick), D Fraunces +
  IBM Plex Mono, E Archivo wide + JetBrains Mono. **Paul picked C, tape
  deck (8 Nov)**, done on the branch: `App/Fonts/` holds
  BigShouldersDisplay-Black, DMMono-Regular and DMMono-Medium (from Google
  Fonts, with their OFL licence files), listed under `UIAppFonts` in
  Config/Info.plist. `Theme.big` uses Big Shoulders (8% larger, it's
  narrow), `Theme.mono` uses DM Mono (regular, or medium for any heavier
  weight); both fall back to the system font if the files don't load.
  Body text stays SF. Still to do: move the ~50 fixed `.system(size:)`
  labels onto Theme (with the style rules), and check nothing is too wide
  for its space on the phone (DM Mono is a little wider than SF).

- Retake the website's Up Next, show and Discover screenshots on build
  124 (new row style, skip keys without circles) and swap them in.
- **Repo back to private on 1 Dec 2026** (Paul, 6 Nov 2026): Paul flips
  it (Settings → General → Change visibility). Not before: November's
  free private allowance is already used, so going private now would stop
  the alerts job and the PR compile check until December. Private costs
  nothing (no card on GitHub, so it pauses at the limit instead of
  charging): alerts ≈ 800 of the 2,000 free minutes a month (26 runs a
  day, each billed as a minute); each Mac PR check ≈ 65 (10×), so run the
  check once per build batch, not on every push. If alerts ever pause,
  move the cron to every 30 minutes. The website is on Cloudflare Pages
  (works with private repos); GitHub Pages stays off.
- (poddeck.uk went out with PR #41 on 6 Nov 2026. Paul added the
  Cloudflare DNS records himself. After the merge: tick Enforce HTTPS in
  Settings → Pages once it's offered.)
- (Bedtime timer default and CarPlay went out in the Friday batch.)
- CarPlay: Apple granted the CarPlay audio entitlement (5 Nov 2026).
  The entitlement is added to `Config/Podcasts.entitlements` on the PR #39
  branch. Before merging, Paul ticks CarPlay on the App ID
  (developer.apple.com → Certificates, Identifiers & Profiles →
  Identifiers → com.gruffaluff.podcasts → Additional Capabilities); check
  with a status_only run that the App ID's capabilities list shows
  CarPlay, or the signed build fails. Done 5 Nov 2026: Paul ticked it;
  status shows CARPLAY_PLAYABLE_CONTENT on the App ID (the API's name for
  the CarPlay audio capability). If the next build's signing complains
  about `com.apple.developer.carplay-audio`, check the profile's
  entitlements first. Build only when Paul says; nothing runs automatically on
  Monday (Paul, 5 Nov 2026).
- **FNB notes also live in Notion** (Personal / Poddeck / FNB, page id
  40f7d696-6c51-80d4-898d-ef27b486ce92). Read only what is below the last
  "✅ Claude read everything above on …" line, then add a new such line
  (date and time) at the end so Paul knows where to add new notes.

## Done from the Notion FNB notes (5 Nov 2026)

Player: one top row (device, find, mark played ✓, ⋯), so the transcript
gets the room (the "transcribed on this iPhone" line is gone); the device
button is now a real AirPlay picker under the label (it did nothing);
scrubbing only by dragging the bold outlined handle on the bar; a
darkening gradient + shadow under white titles over artwork (player and
show header); Undo bar in the player. Mini player: full width, curved top
corners, the player card peeking up (swipe up or tap to open), smaller;
Up Next has the mini player again (now-playing header removed) and, when
empty, suggestions from the charts. Library New Episodes cards: show
colour with artwork on top, paper card sliding over it, keys spaced out.
Tighter rows in Discover and show episode lists. TOP/BTM shadow toned
down in settings. Recent searches on Search (Clear). "Refresh artwork" in
settings (clears the artwork and colour caches). Nothing from the
previous player was lost: Transcript is the ARTWORK / TRANSCRIPT switch,
Chapters / Episode notes / Full transcript are in ⋯ (and the chapter
chip), AirPlay is the device button, Play ad / Not an ad are on the ad
bar. To check on the phone: whether lists still scroll back behind the
mini player (it is now a bottom safe-area inset, so lists should stop
above it).

## Done in the review batch (5 Nov 2026, after build 119)

From Claude's app review plus Paul's Notion notes after 16:55:
- Removed the test auto-follow of Elis James and John Robins on a fresh
  install.
- Text follows the iPhone's text size (Dynamic Type) for `Theme.mono` /
  `Theme.big` text, up to +35% (+20% for big titles), never smaller.
  Text set with plain `.system(size:)` doesn't scale yet.
- Tidy-up: removed unused `NowPlayingHeader`, `PlaceholderView`,
  AddShowView's `ResultRow`, the video clip card (`ClipExporter.video`).
- Player top row: close, device, find, NOTES (scrolls to the notes),
  mark played; download moved beside Full transcript.
- Up Next: reordering only while Edit is on (a long press no longer drags
  a row); the pulled-up list has no numbers, a small NEXT tag instead.
  Its ≡ handles are iOS's own size (can't be made bigger without a
  hand-made reorder).
- Bedtime sleep timer (Shows screen, off by default, Paul): starting an episode
  10pm–5am sets the sleep timer to the last one chosen in the menu (end
  of episode at first).
- Chapters: next / previous chapter for headphones, car and lock screen
  (next/previous-track commands, only when the episode has chapters, so
  on those episodes the lock screen may show track arrows instead of
  10-second skips); a next-chapter key in the mini player.
- "Keep downloads under: No limit / 2 / 5 / 10 / 20 GB" (Shows screen):
  oldest go first: played, then not in Up Next, then the end of Up Next;
  never the one playing (`applyStorageCap`).
- Stats "This week": listened, saved by speed & trims, ads skipped
  (`WeekStats`, on the iPhone, current week only).
- Touch and hold the app icon: Play Up Next, Up Next, Search
  (`QuickActions`; Info.plist `UIApplicationShortcutItems`; the window
  scene uses `QuickActionSceneDelegate`, CarPlay keeps its Info.plist
  configuration).
- Apple-style New Episodes cards (PR #38) go out in this build.
- Paul asked whether progress saves on TestFlight: yes. TestFlight uses
  the same iCloud (CloudKit Production) as a released app; progress,
  Up Next and settings sync on their own (SYNC OK on the Shows screen).
  No Sync now button needed.
- Paul: dark mode not now; holds further changes until Monday unless
  something is game-breaking.

## Done from the fourth Notion FNB batch (5 Nov 2026)

Level bars follow the real sound (`AudioTapState.level`, RMS from the
audio tap, which is always attached; made-up motion only when a stream
gives no reading) and sit centred above the play key. The progress line's
bars show the episode's real loudness once downloaded (`Waveform`: six
quarter-second samples per bar, cached for the session; the fixed pattern
otherwise). Status rows under the player removed; a download key in the
top row (arrow / filling ring / filled when on the phone). Up Next card
opens the full list over the player again, with a handle, "ALL n" and
swipe up. Transcript stats show times only (no episode titles). New
setting (Shows screen): "After an episode, play: Top of Up Next (default)
/ Next in the list" (`afterEpisode`). Mark as played from the player
keeps the place for "Next in the list". Library New Episodes cards, then (after build 119, Paul: "wider and
shorter and more themed like the Apple app"): 300×300, the artwork
filling the card and fading into its own colour, white text over it
(SHOW · 1H AGO, title, one line of description), a translucent play pill
with the time left, download and ⋯; DL/TX lights dropped from the card
(the download key shows downloads); the carousel snaps to each card.
GitHub's free Build check runs on a slower Intel Mac and can fail
("unable to type-check in reasonable time") where Codemagic passes: keep
SwiftUI expressions small either way. Swipe buttons left as iOS draws
them (Paul: leave it for now; options were icons/colours/full swipe, or a
hand-made full-row swipe). Before merging: wait for GitHub's free Build
check on the PR (it runs on PRs), so Codemagic minutes only go on builds
that compile.

## Done from the third Notion FNB batch (5 Nov 2026, after build 116)

Player: no ⋯ menu any more: Full transcript is a key beside the ARTWORK /
TRANSCRIPT switch, the chapter chip shows in transcript mode too, and the
episode page's detail (place in Up Next, download, transcript rows) sits
above the notes under the player. Up Next opens below the player (next 5,
tap to play, "Edit Up Next" for the full list) instead of sliding over
it. Time area: played (big) and left with "ENDS 16:48" (at this speed),
level bars moving between them while playing (`LevelBars`). Pull down
past the top closes the player (`onScrollGeometryChange`; the drag
gesture never fired). Scrub handle 8×32. Transcribe explainer: shorter,
Transcribe on the left, "Not now"; it no longer shows from the root while
the player is open (that closed and reopened the player). Progress: the
transcript status shows "Downloading first · 40%" and "Transcribing ·
62%" with bars (`TranscriptService.progress`, from how far the speech
results have got). Up Next rows keep their height (status line always
there) and the last row has no line under it. Show page and Discover
preview header runs edge to edge up under the status bar with rounded
bottom corners (list ignores the top safe area; search is a field under
the header); the "New episodes go to" bar is gone (the header's settings
key covers it).
Codemagic: free 500 Mac minutes a month. Builds actually take about 5
minutes (Paul checked 6 Nov 2026: 5m16s and 4m52s; the account page showed
100 / 500 used after ~23 builds), so roughly 90–100 builds a month. It
stops at the limit (no charge). Don't press "Enable subscription" on the
Codemagic page: that's the paid plan.

## Done from the second Notion FNB batch (5 Nov 2026, after build 115)

Build 115 confirmed: device button opens the output list, handle-only
scrubbing works. Then: player opens full screen (fullScreenCover, not a
sheet: nothing shows through at the top), with a ⌄ close key and swipe
down on the top area; top keys darker (`NowPlayingView.keyFill`) so they
stand out on artwork; scrub handle smaller (12×38). Transcript panel: the
find box floats over the top of the lines instead of pushing them down,
lines fill from the top (one before, the line now, three after), Back to
now floats at the bottom. Mini player floats over the page with its
colour running down behind the tab bar; lists get bottom room via
`.contentMargins` (the safe-area inset didn't stop them scrolling back
behind it). Up Next rows show episode artwork instead of 01, 02 (ring
when playing); the YOU tag is gone (only TOP1/BTM for auto-added); no
text animation when tapping a row; empty-queue suggestions are separate
rows (several links in one row opened them all, and showed two arrows).
Show page and Discover preview share one header (`ShowHeroBackground`:
artwork filling the card, fading into its colour); FOLLOWING and settings
keys stretch across, bell smaller. Not done: swipe actions as full-row
blocks (iOS 26 draws them as rounded keys; would need a hand-made swipe).

## Done in the "middle ground" build (5 Nov 2026)

New look (above) plus Paul's FNB list: find in transcripts (player panel
and transcript screen: highlights, n of m, next / previous); mini player
steps aside while the keyboard is up (search results were hidden under
it); "Your shows" layout switch (large / card + description / list,
synced `showsLayout`); first-time Transcribe explainer
(`.transcribeExplainer()`, on root and sheets; estimate from this
iPhone's timings); transcription timings (`TranscriptionLog`, on the
iPhone in UserDefaults) in Stats (count, total, per hour of audio,
longest, shortest, latest, stopped); Stop a transcription (`stop` /
`stopAll` in TranscriptService; stopped episodes stay out of the schedule
until Transcribe now; Stop on the transcript screens, STOP TX key, Up
Next and Library menus, "Stop all transcribing" in settings). Also
artwork caching (`ArtworkImageCache`: memory + Caches folder, images at
most 600 points; `CachedImage`) and a bigger URLCache. Built without a
compiler: check the Codemagic log first if the build fails.

## Open questions for Paul

- None open. (Answered: name Poddeck + cassette icon D; earlier: Apple
  Podcasts has no export, links supported instead; speaker labels added
  now, can be removed.)
