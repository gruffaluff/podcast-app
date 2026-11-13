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
screen. Icon (Paul, 12 Nov 2026): **"W1b Warm white, fine edge"**: white
cassette with a thin warm-grey edge, ink window, olive / amber progress
line, soft shadow on the off-white page (`design/icon/icon_w1.png` from
`make_poster_icon.js`; W1 without the edge went out in build 145).
Before that (11 Nov 2026): **"2b olive, soft shadow"**: sand
cassette with spoked reels and the progress line (olive played, amber ad)
on the olive accent with the halftone dot print and a soft card shadow;
`design/icon/poster_2b.png` / `.svg` from `make_poster_icon.js` (node,
Playwright; it also writes the app icon and `docs/icon.png`); also on the
website. Replaced the middle-ground cassette "D" (5 Nov 2026,
`middle_D.png` from `make_middle_icons.py`). Other options looked at:
`middle_options.png` (A–D), `tape_options.png` (reel-to-reel E, big reel
F, tilted G, ink H), `mic_options.png` (reel-to-reel + microphone I–L),
may revisit. Before that: Tape Deck cassette D (`make_deck_icon.py`,
`deck_options.png`); Podspot icons `make_icon.py`, `options.png`). A personal iOS podcast app for Paul's own iPhone, delivered through TestFlight.
It combines the best parts of Apple Podcasts, Spotify, Pocket Casts and
Overcast. Goal: **minimal to look at, fully functional underneath**.

**Look: "Native warm"** (Paul, 11 Nov 2026, late, after build 142: "it
just feels like a lost mess now"; picked direction 1 Native warm from
https://claude.ai/artifact/LkL7nrKf76XCi77TH28Xb3, "just use a standard
Apple font, SF something", rebuild overnight and go straight to a build).
iOS's own parts wherever possible: iOS's tab bar (`TabView` with `Tab`s:
Up Next, Library, Discover, Search as the search tab; it shrinks while
scrolling, `tabBarMinimizeBehavior(.onScrollDown)`) with the mini player
as its bottom accessory like Apple Music (`NowPlayingBar` in
`App/MiniPlayer.swift`: artwork, title, show · time left, play / pause,
skip; tap or swipe up for the player; with nothing playing it offers the
top of Up Next); iOS large titles (`tabTitle`). All type is SF Pro
(`Theme.big` bold, `Theme.title` semibold, `Theme.mono` small medium with
steady figures; the bundled Fraunces / DM Mono files are no longer used).
Sand scheme is now a warm off-white page (#F5F2EC) with plain white rows
(`posterCard` / `deckCard`: white, rounded 12, no colour band, no
shadow). Kept from Deck 0: the dark card for the episode playing, quiet
DL / TX letters, Up Next start times / done-by, Library New / Carry on /
Shows order, the player's artwork top half with TRANSCRIPT / CHAPTERS
swapping in. Player now Apple style: the progress line (`ScrubLine`, ink,
dot at the play point; drag from it to scrub, same rules), time / ends /
left under it, big plain skip / play / skip symbols, Speed / Trim / Boost
/ Sleep as small capsules (filled when on), Transcript / Chapters /
output device as icons; swipe down to close. Build 144: the player is in
the episode's artwork colour, with volume and an Options menu (see
"Done in build 144"). Deck 0's display, chunky
keys, plate and word tabs are no longer used (parts left in
`DeckParts.swift`).
Before that: **"Deck 0"** (Paul, 11 Nov 2026: "lets get the rebuild moving";
mock-ups https://claude.ai/artifact/4o3aSsUdjsA7xxsXYXdVAP and
https://claude.ai/artifact/7Pz2BXFcpRBv9JMsz2m1TA; see "Done in build
142"). In build 142. Everything pressed is in the bottom half
on a deck (`BottomDock` in `App/MiniPlayer.swift`, parts in
`App/DeckParts.swift`): a plate (`Theme.plate`) with the green display
(`LCDPanel`, `LCDProgress`: chapter, time, ends, left, progress blocks
with chapter gaps and amber ads), chunky keys only for skip / red play /
skip (`DeckTransport`, `DeckKeyStyle`), and the tabs as words with a red
underline (`DeckTabs`: Listen, Library, Discover, Search). On Listen the
full deck; other tabs a slim display + play. Rows are paper boxes with a
4 pt band of the show's colour across the top (`posterCard` now draws the
band; `Theme.cardRadius` 12); the episode playing is a dark card
(`playingCard()`, `Theme.playingCard`, moving `PlayingBars`) wherever it
shows. DL / TX are just small letters (`EpisodeLights`). Player: artwork
in the top half, TRANSCRIPT / CHAPTERS shrink it beside the title and fill
the top half (swap with each other), Speed / Trim / Boost / Sleep as one
quiet strip with lights (`ToolsStrip`, `ToolCell`), TRANSCRIPT /
CHAPTERS / output device buttons, swipe down to close.
Before that: **"Poster"** (Paul, 11 Nov 2026: "let's rebuild it all", every
screen at once; mock-ups https://claude.ai/artifact/KbVas33x1ccwvAFM9YoccR,
his pick A + B with square stamps). Same sand page, paper cards, fonts and
colour schemes; every list row is a poster row (`posterCard` / `showRow` /
`PosterRowText` in `App/Poster.swift`): a strip of the show's colour down
the left, a DM Mono label line, the title in Fraunces Soft (type
below),
the artwork as a small square `Stamp` on the right. Big colour areas (Up
Next's playing block, mini player, player, show and preview headers,
episode page, Discover "because you listen to" tiles) are the artwork
printed in one ink of its colour with a halftone dot screen
(`PrintedArtwork`, `Halftone`). Full-row swipes (`posterSwipe`: the action
fills the row, its own height and corners; green add, red played) replace
iOS's round swipe keys on Up Next (right To top, left Played), the pulled-up
Up Next (left Remove), the Library inbox (right Up Next, left Played) and
show pages (right Play next, left Played / Unplayed). Library's New Episodes
carousel became an inbox (Today / Yesterday / This week / Earlier, "All
caught up"). Player: one printed poster, title and chapter now / next at
the top (transcript mode: lyric sheet, line now in big capitals), all
controls in the bottom half (big time, progress line in paper, transport,
SPEED / TRIM / BOOST / SLEEP, TRANSCRIPT / CHAPTERS / FULL / UP NEXT ·
n), notes below. Settings screens stay plain; Top show priority rows have
the show's colour strip. Icons stay SF Symbols (flat, tinted).
Before that: **"Middle ground"** (Paul's pick, 5 Nov 2026; replaced Tape Deck,
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

### Library (option 3, Paul 11 Nov 2026)
- Library tab: HISTORY / STATS keys, then three sections, each opening
  with a big Big Shoulders heading and count on a heavy rule in the
  section's colour (`bigHeading`): **NEW** (olive; the inbox of poster
  rows, small TODAY / YESTERDAY / THIS WEEK / EARLIER labels when more than
  one; tap a row for the episode page, the stamp to play; swipe right to
  add to Up Next, left played; "All caught up" when empty), **CARRY ON**
  (amber; started episodes as slim lines with a progress ring in the
  show's colour, tap to play, `CarryOnLine`) and **YOUR SHOWS** (ink; a
  plain list: small stamp, name, TOP / BTM · n NEW; sort key on the
  heading). Rows get quieter down the page. Mock-ups
  https://claude.ai/artifact/Q8eAX58QyJb4cgPQYqyqAZ.

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

## Done in build 137 (11 Nov 2026, PR #55; Paul: "Build")

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
  holds only the sort key, and "showsLayout" no longer syncs.
- **Alerts job retries Apple blips** (11 Nov 2026; see the alerts notes
  above: waits 20 / 60 / 120 s and tries again on UNKNOWN_CONTAINER,
  429 or 5xx).

## Done in build 138 (11 Nov 2026, PR #56; Paul: "let's rebuild it all", then "build")

- **Poster look on every screen** (see "Look" at the top). Built without
  a compiler (GitHub's check compiles it). To check on the phone: the
  full-row swipes (they're hand-made, so check they don't fight scrolling
  or long-press drag in Up Next), the player on a small iPhone, the dot
  print on light artwork, text sizes in rows, Night colours.
- **New app icon** 2b olive with a soft shadow (top of this file).
- Removed: New Episodes cards (`EpisodeCard`), `panelRow`,
  `Theme.upNextCard`, the player's ARTWORK / TRANSCRIPT switch and Up Next
  card (now keys in the bottom row).

## Done in build 139 (11 Nov 2026, PR #57; Paul after build 138: scrolling "a little jerky / low frameratey"; then "if it's rendering well, let's build")

- **Smoother scrolling**: the dot screen is one small tile repeated by the
  GPU (`Halftone`; it drew every dot, ~22,000 on the player, on each
  redraw); printed artwork is made once per artwork / colour / strength
  off the main thread and shown as a plain picture (`PrintedImages`; it
  was a live grey + multiply blend on every frame); the player's printed
  background is its own view, so the twice-a-second clock no longer
  redraws it (`PosterBackdrop`); only the progress line of Up Next's
  playing block follows the clock (`PlayingProgress`); stamps have a thin
  edge instead of a shadow; artwork colours are measured from a tiny copy
  and saved once things go quiet (it made a JPEG of each picture on the
  main thread and saved the whole list after each one); Library builds
  rows only as they scroll into view (`LazyVStack`).

- **Swipes and scrolling** (Paul: swipes and up / down scrolling "really
  inconsistent and hard to trigger"): the full-row swipes used a SwiftUI
  drag on every row that fought the lists' scrolling and the long-press
  reorder. They now use an iOS pan that only begins when the finger
  starts moving sideways (`SidewaysPan`), so up / down goes straight to
  the list; the line is 80 points (was 96) and a quick flick counts. The
  mini player's swipe up no longer blocks its keys' taps.
- **Transcript glides** (Paul: it "pages away"): the line now changed
  size (15 pt text to 32 pt capitals), so every line below leapt as the
  layout changed. All lines are now the same lyric-sheet capitals and the
  others are shrunk / faded with a scale (no reflow), with a softer
  0.8 s scroll.
- **Library option 3** with colour-coded rules (see Library above).
- **Type: Fraunces Soft** in proper case (see the queue entry below).
- **Own tab bar** (Paul: the bar at the bottom was "still in a white
  capsule", iOS 26's floating glass tab bar): iOS's tab bar is hidden
  (`.toolbarVisibility(.hidden, for: .tabBar)`) and `PosterTabBar` (four
  flat icons with small DM Mono labels, the current tab full strength,
  others faded) sits under the mini player in one printed block with
  curved top corners down to the bottom edge, in the colour of what's
  playing, or the dark display colour with the dot screen when nothing
  is (`MiniPlayerInset.dock`, `DockBackground`). It steps aside while the
  keyboard is up, like the mini player did.

## Done in build 140 (11 Nov 2026, PR #58; Paul's notes after build 139, then "add them, merge, build")

- **Player bottom row steady**: four fixed slots that never change their
  words or come and go (TRANSCRIPT lights up while showing; CHAPTERS and
  FULL TEXT dim when they can't be used; UP NEXT n), icon above label,
  no animation on the switch (they jumped about between artwork and
  transcript).
- **Scrubber only from the play point**: a drag must start within 30
  points of where it's playing (`scrubRefused`); a small paper marker
  shows the point and grows while scrubbing.
- **Tab bar readable**: behind the tabs a plain darker band of the dock's
  colour, no artwork or dots (`DockBackground`); unselected tabs 72%;
  a small bar under the current tab; bar 56 pt.
- **Library Your shows** rule and count in rust (`Poster.rust`), not ink.
- **Opened-row keys visible**: show page episode keys (`EpisodeActions`)
  are sand on the paper rows (paper keys were lost); Up Next row keys
  (`RowKeyStyle`): ink + sand on paper rows, paper main key + dark
  see-through others on the playing block's printed colour.
- **Swipes** (Paul's video, show page): the swipe measured the finger in
  the moving row's own space, so each movement counted twice: the row ran
  ahead of the finger, overshot and jerked. It now measures against the
  window (`translation(in: nil)`). The action block stays on the side the
  swipe began on for the whole swipe and its return (`side`; it flipped
  from Unplayed to Play next as the row sprang back). When a swipe goes
  through, the row slides away first, then the action happens and it
  springs back. Paul's screenshot confirmed the show page keys were paper
  on paper (now sand).
- **Accent question** (Paul: olive clashes with the artwork colours; follow
  the artwork, or neutral soft black?): mock-up
  https://claude.ai/artifact/7VA6NoHBaRi5MSLoEEETMA (olive / soft black /
  follows what's playing). Suggested soft black; following the artwork
  costs nothing noticeable in speed but changes the whole app per
  episode. **Paul: follow the artwork, soft black when nothing plays**
  (11 Nov 2026), on the branch: `Theme.accentFill` / `accentText` read
  `AccentColour.shared` (an `@Observable` holding the playing episode's
  artwork link, set by RootView; its colour comes from `ArtworkColors`,
  already measured for the player), so only views using the accent
  redraw, once per episode. Nothing playing: soft black #2B2925. Night
  scheme: fills follow the artwork, accent text stays Night's light
  green (dark artwork colours would be lost as text on the dark page),
  and with nothing playing it keeps its own accent. Text on the accent is
  paper (artwork colours are darkened for light text).
- **Play key in the show's colour** (Paul, 11 Nov 2026: yes to it, the
  other keys stay neutral ink / sand / paper): the ▶ PLAY / RESUME key
  under an opened show-page episode is filled with that show's artwork
  colour (paper text); on the episode page, which is printed in that
  colour, it's paper with the colour as text (`EpisodeActions.playKey`,
  `ColourKeyStyle`). Ink until the colour is known.
- **Colour rule for keys** (Paul, 11 Nov 2026, "follow that guidance"):
  on a screen about one show (show page, episode page, show settings
  sheet) the colour comes from that show; everywhere else from what's
  playing, soft black when nothing is. Only the main "do it" key (play)
  and keys / switches that are on or chosen get colour; every other key
  stays neutral ink / sand / paper. Built with `\.showColour` (an
  environment value set by ShowView, EpisodeNotesView and
  ShowSettingsView) read by `KeyButtonStyle(.accent)`, `DeckSwitch` and
  `DeckTag` through `Theme.showAccentFill / showAccentText /
  showOnAccent`. Night keeps its light accent text.
- **Nothing changes colour on screen** (Paul, 11 Nov 2026: "I don't want
  someone to open a page and the colour changes"): show page, show
  preview, episode page and show settings fix their colour when they open
  (`pageColour` / `colour` set in `init` from the saved colour); if it
  isn't known yet the page stays neutral for that visit and it's measured
  for next time. Every followed show's colour is measured ahead at launch
  and after each feed check (`LibraryStore.preloadShowColours`; tiny copy,
  once per show, saved), and rows with a stamp measure theirs as they
  appear, so pages normally open in their colour. The colour of what's
  playing changes only when a different episode starts, with a 0.5 s fade
  (`AccentColour.colour` is now set by RootView inside `withAnimation`).

## Done in build 141 (11 Nov 2026, PR #59; Paul's notes after build 140, then "build")

- **Dead zone above the mini player** (scrolling an inch above it did
  nothing) and **rows stuck behind the mini player** in Up Next (the
  taller playing block pushed the list down): iOS's TabView is gone. Our
  own tabs (`RootView.tabPage`: a ZStack, each tab made the first time
  it's shown and kept, only the current one touchable), so no hidden iOS
  tab bar sits under ours; the dock is a bottom safe-area inset
  (`MiniPlayerInset`, was an overlay + content margins), so every list
  stops above it and its last row scrolls clear. Undo / No internet bars
  float just above the dock without taking room. Check on the phone:
  scrolling just above the mini player, the last rows of every tab,
  switching tabs keeps each tab's place.
- **New in Library lasts two weeks** (Paul, 11 Nov 2026): episodes leave
  New 14 days after they came out (`LibraryView.newFor`), as well as when
  played; they stay unplayed on their show page (and in Up Next).
  Leaving out episodes already in Up Next: no (Paul: everything goes to
  Up Next by default, so New would be empty). Before the inbox, the New
  Episodes carousel used the same rule (unplayed, since following plus
  each show's newest, 12 at most) with no time limit.
- **Your shows sort menu** (Paul): the tick pushed the chosen line's
  words to the right; now two iOS pickers in the menu (Name A–Z / Z–A,
  Newest / Oldest episode first) with iOS's own tick column. Sorting by
  when you followed is gone (an old saved choice falls back to A–Z).
- **Bottom of the screen** (Paul: half printed artwork behind the mini
  player, half plain band behind the tabs "looks a little off"): options
  on https://claude.ai/artifact/FwkMBnaiwmK8SdbGbgRgW4: Now, A one print
  fading down, B one colour with the dot print all the way (suggested),
  C mini player as a floating card over a dark tab bar, D printed mini
  player over a paper tab bar. **Paul picked A** (11 Nov 2026):
  `DockBackground` is one `PrintedArtwork` under the whole dock with a
  black gradient (clear for the top 40%, 34% at the bottom); nothing
  playing: display colour + dots with the same darkening.
- **Carry on and Your shows look** (Paul, 11 Nov 2026: doesn't like how
  they're shown): options on
  https://claude.ai/artifact/SbZUnVKhQJPYuS8Hv4hZKw. Carry on: Now (slim
  lines with a ring), C1 small printed cards sideways, C2 one big printed
  card for the latest then small rows (suggested), C3 poster rows with a
  progress edge, C4 progress rings round the artwork. Your shows: Now
  (plain list), S1 artwork grid three across, S2 colour tiles two across
  (suggested), S3 poster rows like New, S4 record shelf of spines.
  The same page now shows the whole Library at full size with pickers.
  Paul likes C2 and S2 or S3, and asked for New options first (same
  link): Now (poster rows by day), N1 compact inbox, one line each on a
  paper card (suggested), N2 printed cards sideways, N3 grouped by show,
  N4 "morning paper" card with Add all / Mark all played, N5 stamp shelf
  three across. **Paul picked N4, C2, S3** (11 Nov 2026), built in
  LibraryView.swift: `NewPaper` (one printed card in the colour of
  what's playing, display colour when nothing is: "n new episodes",
  "LAST TWO WEEKS · 2H 20M TO LISTEN", a line per episode
  (`NewPaperLine`: tap for the episode page, stamp plays, swipe right Up
  Next / left played, hold for the menu), ADD ALL TO UP NEXT (only those
  not queued, oldest first, Undo) and MARK ALL PLAYED (Undo));
  `CarryOnBlock` (`CarryOnCard` printed in the show's colour with a big
  play key and progress, then `CarryOnSmall` rows with a thin bar);
  `ShowPosterRow` (colour strip, where new episodes go, name in the title
  font, n NEW pill in the show's colour, stamp). The day-grouped inbox
  rows (`InboxRow`) and `CarryOnLine` are gone.
- **Add to Up Next never duplicates or moves** (Paul, 11 Nov 2026): Up
  Next never held duplicates, but Play last / Add to Up Next on an
  episode already in it moved it to the end; now it does nothing
  (`LibraryStore.playLast` returns early). Play next still moves it up.

## Done in build 142 (11 Nov 2026, PR #60; Paul: "Build"; Paul's notes after build 141 + the Deck 0 rebuild)

- **Dead spot still there** (Paul's build 141 screenshot: swiping up /
  down did nothing from about the dock's height above the mini player
  down to it). Both earlier tries put the dock over the lists (an
  overlay, then a bottom safe-area inset), and each left a strip about
  the dock's height that scrolling ignored. Now the dock isn't attached
  to the tabs at all: RootView is a VStack of the tabs (ZStack) and
  `BottomDock` underneath (`App/MiniPlayer.swift`, was the
  `MiniPlayerInset` modifier on every tab), so nothing overlaps any list.
  Undo / No internet bars float over the bottom of the tabs. Check on
  the phone: scrolling right down to the mini player on every tab.
- **ADD ALL TO UP NEXT invisible** when every new episode was already
  queued (a dimmed paper key on the card): it now reads "✓ ALL IN UP
  NEXT" in the same light-on-dark style as Mark all played.
- **Instead of the dots?** (Paul, 11 Nov 2026: "do we drop this dot
  image stuff"): finishes for the big colour areas on
  https://claude.ai/artifact/28nNe6nbWSbieb2u55qxuo: Now dots, F1 flat
  colour, F2 soft tone (light-to-dark wash; suggested), F3 artwork glow
  (blurred blooms, like Apple Music), F4 paper grain, F5 smooth print (no
  dot screen), F6 flat colour with a darker top edge. Waiting on Paul.
- **Fresh start?** (Paul, 11 Nov 2026: "I feel like I'm overthinking and
  over engineering … happy for you to completely scrap whatever we've got
  and redesign from the ground up"; keep every feature, minimal but very
  functional, look and feel good). Five directions, each with Up Next,
  player and Library, on https://claude.ai/artifact/LkL7nrKf76XCi77TH28Xb3:
  1 Native warm (iOS's own lists, swipes, tab bar, sheets on off-white
  with Fraunces titles; suggested: fewest bugs, smooth), 2 Paper
  (magazine page: numbered ruled lines, no cards, colour only in the
  player), 3 Night studio (dark, artwork glow behind what's playing),
  4 One screen (playing card + Up Next with filters on home; two tabs,
  Listen and Library), 5 Deck refined (cassette deck: LCD, chunky keys).
  Common to all: three tabs (Up Next, Library, Discover; search inside
  Library / Discover), one main thing per screen, player tools (speed,
  trim, boost, sleep) in one Tools sheet, iOS's own parts where possible.
  Supersedes the dots question if Paul picks one. Paul: likes 1 Native
  warm, 2 Paper, 4 One screen (asked whether everything fits: yes, see
  reply) and 5 Deck; not 3 Night studio; asked for more practical ideas
  to combine. Round 2 on the same link: 6 Checklist (like Things: Now /
  Today / Later groups, show colour dots, round played ticks), 7 Timeline
  (Up Next against the clock: when each starts at your speed, "all done by
  22:10"), 8 One sheet (like Apple Maps: one sheet slides up in three
  steps, mini player / player / player + Up Next, transcript, chapters),
  9 Utility (like Overcast: white, one orange, text buttons, big
  targets), 10 Reader (transcript-first player with a small dark dock;
  saved quotes in Library). Paul: likes 1 for simplicity, 4 for the one
  screen idea, 5 for the look; asked for blends of those three. Five on
  https://claude.ai/artifact/WpuLkbzDfjtBqTpHsUBNMP (two tabs, Listen and Library; Listen = what's playing + a
  list switching Up Next / New / Carry on): A Deck on top (faceplate with
  display + keys above the list), B Quiet deck (calm white-card app,
  deck only in a slim dark display strip, mono labels and one red play
  key; suggested), C Cassette card (what's playing as a cassette with
  turning reels), D Deck with modes (fixed faceplate, mode keys UP NEXT /
  NEW / CARRY ON / SHOWS switch the list, no tab bar), E Plain home, deck
  player (deck saved for the full player). Paul: "not feeling any of
  those; I want to feel wowed by how well thought out this is, how
  smartly the space is used, functional and beautiful". Instead of more
  options: one design worked through as a clickable prototype with the
  reasoning beside each screen, https://claude.ai/artifact/Bui2H2iQBjQMtNQogtC1XJ:
  iOS 26's own floating tab bar with two tabs (Listen, Library) and a
  search button; Listen = what's playing as one card (chapter, time left,
  play, progress split at chapters) + one list switching Up Next / New /
  Carry on, with Up Next showing when each episode starts at your speed
  and "done by 22:10"; player = artwork square that flips to the
  transcript in place, chapter pill, progress with chapter gaps and amber
  ads, "ends 19:42", tools as four buttons showing their state (1.3×, On,
  Off, 20 min), AirPlay / Up Next / Notes along the bottom; Library = one
  search for shows, episodes and transcripts, show tiles with new counts,
  Discover suggestions, History / Stats / Settings cards; show page =
  setting pills (Top of Up Next, alerts, own speed), round played ticks.
  The artwork colour is the only colour. Paul: not sold;
  asked to evolve Deck refined and look for any other angle. Three
  evolutions on https://claude.ai/artifact/2UbLpBxfdCPjyEyvUAX3Us, each with
  Listen, player and Library: A Hi-fi component (light panel, small amber
  display, crisp keys with little lights for SPEED / TRIM / BOOST / SLEEP,
  one orange; suggested), B Walkman (deep blue body, chunky keys, a cassette
  window whose tape shows progress, Up Next as tapes, shows as spines on a
  shelf, yellow for play), C Tape machine (Up Next as a length of tape down
  the screen with start times and a red NOW line, chapters as edit marks,
  Library shows the week as tape). Paul: Deck refined is above these;
  asked for Deck refined itself plus ideas built on it:
  https://claude.ai/artifact/KpAQizmVHCuGD9Ku6AdnpN.
  0 Deck refined worked through (Up Next with the display and
  start times, player, Library, show page; parts: green display for live
  things only, keys that latch with a red light and show their value,
  numbered paper rows, mono labels, one red play key), 1 Labelled tapes
  (rows as cassette labels with a band in the show's colour), 2 Faceplate
  (one screen: fixed deck on top with UP NEXT / NEW / CARRY ON / SHOWS
  mode keys, no tab bar; pull down = player), 3 Quiet deck (plain lists,
  deck only in the mini player and player), 4 Display does more (a DISP
  key switches the player's display between TIME / TEXT / CHAP).
  Suggested 0 with 4's player. Paul: for reach, the player and keys
  must be at the bottom of the screen. All five reworked bottom up on
  https://claude.ai/artifact/XftkojHeUgsmXaSYTuGH1e (rule: top is for
  reading, bottom is for pressing): a fixed deck along the bottom of every
  screen (display, play / skips, tabs), lists scroll above it with Up Next
  sitting on the deck (next episode nearest the thumb), Library and show
  search boxes on the deck, show settings keys on the deck, the player =
  the same deck pulled up (artwork up top; display, transport, tools and
  ⌄ Close key in the bottom half). Faceplate keeps its mode keys at the
  very bottom; DISP display sits just above the keys. A "Show thumb
  reach" switch overlays the easy / stretch / hard zones.
  **Paul picked 0** (11 Nov 2026) with notes: no shows as tapes on a
  shelf; Up Next as 1's colour-coded boxes but without the paper effect;
  shows like 1 (two-across boxes); keep the keys but don't let it feel
  like a calculator; player artwork takes the top half and shrinks for
  the transcript, like Apple Podcasts. Refined 0 on
  https://claude.ai/artifact/4o3aSsUdjsA7xxsXYXdVAP (player clickable):
  plain cards with a 4 pt band in the show's colour (Up Next, Carry on,
  New, show episodes; played ones grey), shows as two-across boxes with
  the band; three weights of control: chunky keys only for skip / red
  play / skip, Speed / Trim / Boost / Sleep (and the show page's Goes to
  / Alerts / Speed / Keep) as one quiet strip with a light each, Text /
  Chapters / Up Next / AirPlay / Close as plain icons, tabs as words with
  a red underline; the green display stays. Player: artwork ~196 pt in
  the top half with the title under it; TEXT (or tapping the artwork)
  shrinks it to a 44 pt square beside the title and the transcript fills
  the top half (speaker label, line now bigger and dark, others faded).
  Paul's notes on that (11 Nov 2026), round 2 on
  https://claude.ai/artifact/7Pz2BXFcpRBv9JMsz2m1TA: player has no Close
  (swipe down) and no Up Next key (swipe down, Listen tab); three
  buttons: TRANSCRIPT, CHAPTERS, output device (AirPlay); transcript and
  chapters each fill the top half and replace each other (tap again for
  the artwork). Keep the DL / TX lights (`EpisodeLights`) and similar
  bits: on every episode row and under the player's title. Playing
  episode highlighted in the theme's highlight colour (a dark card with
  moving bars) wherever it shows: Up Next, Carry on, New, show pages.
  Up Next: no numbers, reads top-down (playing first, then the top of the
  queue), start times and "done 22:10" stay. Library order: New, Carry
  on, Shows (most recently updated first, TOP / BTM and n NEW pill like
  today). New styles mocked: A Boxes (colour-band boxes, newest three +
  "All 6 new"; suggested), B Front page (one dark card with Add all /
  Mark all played, like today's New), C By day (Today / Yesterday / This
  week compact lines with colour dots), D Row of squares (sideways
  artwork with +). Paul: DL / TX must be subtler (just the small
  letters, faded or not); see more of B and C with the show art on the
  right so New looks different from Carry on. Same link updated: DL / TX
  are plain small mono letters (dark when done, faded when not, dotted
  while on the way); New lines have the words left and the artwork on the
  right; B Front page in dark and in paper (newest four, Add all / Mark
  all played, "All ›" opens the full New list with both actions on the
  deck at the bottom); C By day plain lines plus one mid-swipe (green
  + UP NEXT). Suggested B on paper (dark stays for what's playing).
  **Paul picked B on paper** (11 Nov 2026). The Deck 0 design is now
  settled (summary): bottom deck on every screen (green display, chunky
  skip / red play / skip, tabs as words); colour-band boxes for episode
  rows and shows; playing episode as a dark highlight card with moving
  bars everywhere; quiet DL / TX letters; Up Next top-down, no numbers,
  start times + done-by; player artwork top half, TRANSCRIPT / CHAPTERS /
  output device buttons (transcript and chapters swap into the top half),
  tools strip with lights, swipe down to close; Library = New (paper
  front-page card, art on the right, newest four, Add all / Mark all
  played, All › full list with actions on the deck), Carry on, Shows
  (recently updated, TOP / BTM, n NEW pill); search and show settings on
  the deck. Not built yet: waiting on Paul's go to start the rebuild
  (new branch, separate from PR #60).
- **Deck 0 built** (Paul, 11 Nov 2026: "lets get the rebuild moving"). On
  this branch with PR #60 (this session can only push to its one branch,
  so the dead-spot fix and the rebuild go out together). Built without a
  compiler: GitHub's check compiles it. What changed:
  - Bottom deck (`BottomDock`): plate, grab handle, full deck on Listen
    (`DeckNowDisplay` + `DeckTransport`), slim on other tabs (`SlimDeck`:
    small display + red play), tabs as words (`DeckTabs`); tap the display
    or swipe up for the player; Skip ad sits on the display during an ad.
    The printed dock, `MiniPlayer` and `PosterTabBar` are gone.
  - Up Next: no numbers, top-down, each row artwork left (tap plays),
    title, show · tag · length, date + status, and on the right when it
    starts at the current speed ("NOW" for the one playing / first) with
    the DL / TX letters; header "n EPISODES · DONE BY 22:10"
    (`UpNextTimes`); playing row = dark card with bars and its progress.
  - Player (`NowPlayingView` rewritten): no close key (pull down) and no
    Up Next key; top keys find (transcript) / download / mark played; the
    artwork (matched move) and centred title, show · chapter line (opens
    the show) and DL / TX; TRANSCRIPT and CHAPTERS modes fill the top half
    (`PlayerTranscriptPanel(light: true)`, new `PlayerChaptersPanel` with
    the playing chapter as the dark card and a link to the full Chapters
    list with its From the show / Auto switch); saved as "playerTopMode"
    (synced, replaces "playerShowsTranscript"). The display shows the time,
    ends and left over the progress; drag from the bright mark to scrub
    (same rules as before: only from the play point, finger below slows
    it, Undo for 2 min+ jumps, chapter + time bubble). Chapter skip keys
    left out of the transport (chapters panel, headphones and lock screen
    still skip chapters). Episode notes still below.
  - Library: small mono section labels (NEW · 06 …); New = paper card
    (`NewPaper`: newest four, artwork on the right, "4H 10M · ALL ›" opens
    `NewListView` with Add all / Mark all played at the bottom); Carry on
    = boxes with a progress line, the playing one first as the dark card;
    Your shows = boxes (artwork left, TOP / BTM · UPDATED 2H AGO, n NEW
    pill), most recently updated first by default (new key "showsOrder",
    synced; menu says "Recently updated first").
  - Show pages: the playing episode's row is the dark card.
  - Every other list (Discover, Search, history, storage, chapters…)
    picks up the colour-band boxes through `posterCard`.
  - Not changed yet: show / preview / episode page headers still printed
    in the show's colour; Discover and Search rows keep the artwork on the
    right. To check on the phone: deck height on smaller iPhones, the
    player's top half with long titles, scrubbing on the display, Night.

## Done in build 143 (11 Nov 2026, night, PR #61; Paul: rebuild overnight in Native warm, then build)

- **Native warm** (see "Look" at the top). Built without a compiler;
  GitHub's check passed first time; merged straight to a build (Paul's
  say-so).
  To check on the phone: the iOS tab bar and mini player (Paul disliked
  iOS 26's floating glass tab bar in build 138; this is the native look
  he asked for, but say if the capsule still bothers him), Undo bar
  placement above the tab bar (fixed 128 pt lift), text sizes now in SF,
  the player's progress line and buttons, Night.

## Done in build 144 (12 Nov 2026, PR #62; Paul: "Merge")

Paul's queued notes after build 143, built without a compiler (GitHub's
check compiles it):
- **Player in full colour** (Paul picked A on
  https://claude.ai/artifact/FU45FUnYLfGc2K41NUnt5q; no rounded-square
  play key): the whole player is the episode's artwork colour
  (`ArtworkColors`, already darkened for light text), a little darker
  towards the bottom; text, icons, progress line and play symbol in paper;
  lit buttons paper with the colour inside, others see-through light.
  The colour is set when the player opens / the episode changes
  (`NowPlayingView.colour`), neutral dark (#2C2A26) until measured, then
  fades in once. Transcript and chapters panels use light text. The
  status bar is hidden in the player (dark status text would be lost on
  the colour; a colour-scheme preference there can flip the whole app).
  Episode notes sit in a paper card below.
- **Player reshuffle**: a transcript key beside download in the top keys
  (TX to transcribe now; a ring while it's on its way, tap to stop;
  filled when there's a transcript, tap to show it); the iPhone's own
  volume (`SystemVolumeSlider`, `MPVolumeView`) where Speed / Trim /
  Boost / Sleep were, speaker icons at each end, a little narrower than
  the line; bottom row Options · Transcript · Chapters · AirPlay, with
  Options a menu holding Speed (choices), Trim, Boost and Sleep (timers,
  5 more minutes), lit when any is on; no Up Next key: the next three in
  Up Next with start times sit above the notes (`PlayerUpNextCard`, tap
  to play, All › pulls up `UpNextSheet`).
- **Show page**: plain header on the warm page (artwork 96 pt, name in SF
  bold, publisher · episodes · auto download, Following / Top / bell
  keys, description); the printed block and the gap above it when pulled
  down are gone. Following and a lit bell take the show's colour, the
  settings key is neutral. (Discover's show preview still has the
  printed header.)
- **Episode page**: artwork 64 pt + "Show ›" + date · length, the title
  in SF semibold 22 pt as the feed writes it (up to 4 lines), DL / TX, one
  wide Play / Resume (Pause when on) key in the episode's colour with
  small Play next and Played keys (`EpisodePageKeys`); download,
  transcript and Up Next only in the status rows below.
- **Library**: New lasts one week (`LibraryView.newFor`); History and
  Stats are icons in the title bar beside + (their own row left gaps);
  Carry on artwork has a play / pause icon (soft dark circle).
- **Download % no longer shifts Up Next rows**: the DL / TX letters keep
  the room of "DL 100%" / "TX WAIT" (`EpisodeLights`).
- To check on the phone: the player colour on light and dark artwork,
  the volume slider (it only shows on a real iPhone), the Options menu,
  the show page top when pulled down.

## Done in build 145 (12 Nov 2026, PR #63; Paul: "build")

- **App icon W1 "Warm white"** (Paul, 12 Nov 2026, from
  https://claude.ai/artifact/C3kwySgwiAzrEcWyByRrnt: Now, W1 Warm white,
  W2 Clean olive, W3 Ink on white, W4 Olive on white): the same cassette
  in white with an ink window and white spoked reels, lifted by a soft
  warm shadow off the app's off-white (#F5F2EC), olive played line and
  amber ad; no dot print. `design/icon/make_poster_icon.js` now writes
  `icon_w1.svg` / `.png`, the app icon and `docs/icon.png`; the
  website's two inline logos are the new one (claude.ai page
  republished). 

- **DL / TX letters fill in** (Paul, 12 Nov 2026, build 144 screenshots of
  Up Next and Library: the letters sat far apart, because build 144 gave
  each the room of "DL 100%" / "TX WAIT"; picked option 4 of: % in place,
  progress circle, line underneath, letters fill in): back to just "DL"
  and "TX" side by side; faded when not done, dark when done, and while
  downloading / transcribing the letters darken left to right with the
  progress (`EpisodeLights.light`, a masked copy). Nothing changes width.


## Done in build 146 (12 Nov 2026, PR #64; Paul: "Build")

- **Dragged Up Next rows: just the card** (Paul, 12 Nov 2026, build 145
  screenshot of the pulled-up Up Next: the lifted row had a light square
  round the card). Both reorderable Up Next lists use `reorderCardRow()`
  (Deck.swift): clear row background and a rounded `.dragPreview` shape
  the size of the card. (Builds 124 / 127 tried a drag shape on rows that
  filled the cell; these rows are cards inside the cell, so the shape is
  the card.) Check on the phone that the lifted card isn't see-through.
- **Titles level with the top buttons** (Paul, 12 Nov 2026: "Up Next
  level with the buttons at the top"): `tabTitle` uses
  `.toolbarTitleDisplayMode(.inlineLarge)`, so Up Next, Library,
  Discover and Search show their big title on the bar's own line and
  the content starts higher.
- **Mini Up Next matches the Up Next tab** (Paul, 12 Nov 2026, after the
  options on https://claude.ai/artifact/HzhNwdFKAN7LRg9S8E71Xt: "match the
  main Up Next in style and theme"): `PlayerUpNextCard` rows are the tab's
  white cards (`posterCard`): 40 pt artwork, title (2 lines), SHOW ·
  LENGTH, start time and DL / TX on the right; the "UP NEXT · n" label and
  All › stay light on the player's colour. No see-through box round them.
- **New card roomier** (Paul, 12 Nov 2026: "looks cramped"): `NewPaper`
  padding 16 / 14 (was 12 / 10), lines 12 pt top and bottom (was 8),
  artwork 44 pt (was 36), title 17 pt like Up Next, label 9 pt, more room
  above the keys.

- **Icon W1b "fine edge"** (Paul, 12 Nov 2026: the white cassette was "a
  little lost"; picked W1b from
  https://claude.ai/artifact/PS3G7LXAN1QLxAfbNPG8Ei over W1a deeper shadow,
  W1c darker tile, W1d sand tile + edge): W1 with a thin warm-grey edge
  (#CFC6B4) round the cassette and a slightly stronger shadow.
  `make_poster_icon.js` re-run (app icon, `docs/icon.png`,
  `design/icon/icon_w1.png`); website logos updated and the claude.ai
  page republished.

## Done in build 147 (12 Nov 2026, PR #65; Paul: "Build")

- **App icon badge** (Paul, 12 Nov 2026: "badges for those who want it";
  options https://claude.ai/artifact/RnVevs4sFdvbMpeXBfnbM6, in-app
  layouts https://claude.ai/artifact/7zcUA9zfezfFkToa3HkVhJ; **Paul picked
  A**). Shows screen section "Badge on the app icon"
  (after Checking for new episodes) with one row: a tiny icon preview
  (`IconPreview` image, the W1b icon at 120 px) showing today's number,
  then "Badge" and the sand ▾ list key (`BadgeSettingRow`); the footer
  says what the choice counts. `App/Badge.swift`: `BadgeMode` Off
  (default) / New since last open / New episodes (Library's New) / In Up
  Next / Downloaded, not played / Top shows only / Hours left in Up Next
  (at your speed, rounded up) / Only when something's wrong (feeds that
  couldn't be fetched in the last check, saved by `refreshAll` as
  "badgeFailedFeeds"). `AppBadge.update` sets the number (0 clears it):
  on opening the app (which also restarts "since last open"), going to
  the background and after every feed check (so the background check and
  the alerts job's quiet push update it too). iOS asks once to allow
  badges when a mode other than Off is chosen. Kept on this iPhone only
  ("badgeMode", not synced). Free. If the icon changes, re-make
  `IconPreview.png` from `design/icon/icon_w1.png`.

- **Volume slider tidy** (Paul, 12 Nov 2026, build 146 screenshot: the
  speaker icons sat below the line and iOS's thumb was big): the slider
  is centred in its box (`CentredVolumeView` overrides
  `volumeSliderRect`), so it lines up with the icons; its dot is the
  progress line's (12 pt paper circle, 20 pt while held) on a 4 pt
  rounded track (`SystemVolumeSlider`).

- **Player artwork edge to edge** (Paul, 12 Nov 2026, with a screenshot
  of Apple Podcasts' player: "artwork bigger and blends into the rest of
  it"): in artwork mode the episode's artwork fills the width from the
  very top (under the hidden status bar), square, and fades into the
  player's colour over its lower third (`NowPlayingView.heroArtwork`,
  behind the first screenful, so it scrolls away with it); a light shade
  at the top keeps the keys visible on pale artwork. The title (24 pt,
  left-aligned like Apple's) and show · chapter line sit at the foot of
  the fade, just above the progress line. Transcript / chapters modes
  are unchanged (plain colour, small artwork beside the title). On the
  branch.

- **Player Options panel** (Paul, 12 Nov 2026: the Options menu "doesn't
  look good"; expand as a menu underneath): Options opens a panel under
  the bottom row (`NowPlayingView.optionsPanel`): Speed with − / value /
  + (tap the value for 1×; says THIS SHOW for a show's own speed), Trim
  silences and Boost voices as chips (filled when on), Sleep as chips
  Off / 5 / 15 / 30 / 45 / 1h / End with "+5 min" while a timer runs.
  Tap Options again (a ⌄) to close; the artwork area shrinks to make
  room. The iOS menu is gone.
- **Player Up Next clearer** (Paul, 12 Nov 2026: not clear whether you
  change it on the player or click through; picked "3 then +2 more"):
  the next three stay (tap to play), the heading's key says Edit, and
  under them "+ 2 more · Reorder or remove" opens the pulled-up Up Next.
- **Pulled-up Up Next rows** (Paul's recording, build 146: text redrew
  while dragging; wants bigger rows like the other screens): rows are the
  Up Next tab's own (`QueueRow`, now shared): 40 pt artwork, 2-line
  title, show · tag · time, date, start time and DL / TX; tap plays. The
  NEXT tag that moved between rows mid-drag (the redrawn text) is gone.
- **Show preview pulled down** (Paul, 12 Nov 2026: pull down on screens
  without refresh; normal iOS bounce, but the preview showed a sand gap
  above its coloured header): the gap fills with the show's colour.

## Done in build 148 (12 Nov 2026, PR #66; Paul: "Let's build")

- **Player artwork below the keys** (Paul, build 147 screenshot: the
  artwork ran to the very top and the download / transcript / played
  keys were lost on busy artwork): the edge-to-edge artwork now starts
  just under the top keys (status bar height + 44 pt), so the keys sit
  on the plain colour; the dark shade at the top is gone. Its fade also
  ends nearer the title.

- **Mini player with nothing playing: B** (Paul, 12 Nov 2026, from
  https://claude.ai/artifact/WiCp8oqMHFgCfg5g6FEVP3; he'd missed the old
  "Tap to play Up Next" line): the bar shows the top of Up Next ready to
  play: its artwork and title, "Up next · Show · 26m" (or "Carry on ·
  12m left" once started) and a play key in a ring that shows how far
  through it is (`NowPlayingBar.upcoming`). Tap the bar or the key to
  play it. "Up Next is empty" when there's nothing.

## Done in build 149 (12 Nov 2026, PR #67; Paul: "Build")

- **Player top A + Options D** (Paul, 12 Nov 2026, from
  https://claude.ai/artifact/PjNiXZeWYQUL7GqMeyHJkk, shown with the
  Tailenders artwork; build 148 had a plain band then a hard edge, and
  opening the Options panel slid the title and progress line over the
  stretched artwork). A: the artwork is a big rounded card again
  (`artwork(item, size:)`) with the title left-aligned under it, on a
  soft blurred copy of itself spread across the top and fading into the
  player's colour (`NowPlayingView.artworkGlow`, like Apple Music); the
  edge-to-edge `heroArtwork` is gone. D: Options opens a short sheet
  (`PlayerOptionsSheet`, half height, swipe down or Done): Speed as one
  "− 1.2× +" control with quick picks 1× / 1.2× / 1.5× / 2× (lit in the
  accent), Trim silences and Boost voices as switches with a line each,
  Sleep timer as one row with a list (Off, 5–60 min, End of episode) and
  "5 more minutes" while it runs. The in-player panel is gone, so nothing
  on the player moves. Paul: keep labels like "Options" centred under
  their icons (the mock-up's weren't; the app's are).

## Queued for the next app build

- **Smoother swipes and Undo** (Paul's recording, 13 Nov 2026, build
  149: swiping an Up Next row to Played, the row vanished in one jump
  and the rows below leapt up; Undo popped it back; the Undo bar popped
  in and out). Every change that can be undone (`LibraryStore.undoable`)
  and every full-row swipe action (`PosterSwipe`) now happens inside one
  animation (`LibraryStore.listChange`, snappy 0.32 s), so lists close
  up, move and reopen smoothly, Undo included; the Undo bar slides up
  from the bottom and away (`UndoBar`). Show pages (Paul's second
  recording): the swipe was put on inside the row's white card, so only
  the words slid and they ran over the coloured action block; the swipe
  is now outside the card (`ShowView` `leadingSwipe` / `trailingSwipe`),
  so the whole card slides, like Up Next. On the branch.

- **Options sheet tidied** (Paul's build 149 screenshot, 13 Nov 2026:
  blue icons and + didn't fit, the see-through glass was too cloudy, and
  the sleep timer was hidden until you swiped up): `PlayerOptionsSheet`
  is now one compact layout sized exactly to its contents
  (`presentationDetents([.height(measured)])`), so everything shows at
  once; solid warm page (`presentationBackground(Theme.background)`) with
  white cards; icons, − / + and Done in ink, the chosen quick speed and
  switches in the accent; no footers; "+5" beside the sleep timer while
  it runs. On the branch.

- **Rows one size everywhere** (Paul, 13 Nov 2026, two player Up Next
  screenshots: a one-line title made a shorter row; "keep these rows a
  consistent size regardless of text … apply this rule throughout. If it
  needs to be bigger, so be it"). Episode titles always take two lines'
  room (`.lineLimit(2, reservesSpace: true)`): Up Next tab and pulled-up
  (`QueueRow`), the player's Up Next (`PlayerUpNextCard`), Library's New
  card, and every `PosterRowText` (show pages, show previews, now 2 lines
  not 3, Search, Discover, History, Storage, Chapters, suggestions), whose
  label line is also always there. Show page rows always keep their notes
  line and DL / TX line (blank / hidden when there's nothing). Carry on
  rows were already one line each. On the branch.

- **Going live** (Paul, 12 Nov 2026: "hopefully we are sort of done
  developing mostly", asked next steps / timeline). Told him: three ways
  (stay personal on TestFlight, builds expire after 90 days; public
  TestFlight link, up to 10,000, light first review; App Store), suggested
  public TestFlight with friends for 1–2 weeks then the App Store.
  **Must fix first**: instant alerts are single-user (one public
  "follows" record, `PoddeckAlertEpisode` records seen by every
  subscriber), so others would get Paul's alerts and theirs wouldn't
  work: limit instant alerts to Paul; everyone else uses the background
  check. Store listing to do: name check, subtitle / description /
  keywords, privacy policy + support page on poddeck.uk, 6.9" screenshots
  (no third-party artwork), App Privacy answers (mostly none), age
  rating, EU trader status (free, not a business: non-trader keeps his
  address off the store), version 0.1 → 1.0. Costs: developer
  membership (already paid yearly) + domain; free app has no other fees.
  Waiting on Paul: public TestFlight first or straight to the store.
  Alerts for everyone (Paul asked if it needs a server): not at first.
  Same free GitHub job, made multi-user: each phone saves its own sealed
  follows record under a random ID; the job fetches each feed once and
  writes one alert record per follower tagged with that ID; each phone's
  CloudKit subscription filters on its own ID. Fine for tens to a few
  hundred users; GitHub's loose timing stays; using free Actions as a
  service for others is a grey area; after the repo goes private its
  minutes count. Bigger: same job on a hosted timer (e.g. Cloudflare
  Workers paid, $5 / month). Simplest for launch: instant alerts only
  for Paul, everyone else on the background check. Paul: "just
  interested in steps for now".



- **Sandier app?** (Paul, 12 Nov 2026: "if we added a sandy tinge to the
  app, add some colour"): https://claude.ai/artifact/RRkrs9ZBPtpjRtF4QFMjCN,
  Up Next and Library in Now (#F5F2EC page, white cards), S1 Light sand
  (#EEE7D9 page, white cards), S2 Sand + olive (S1 plus olive #45543A for
  the selected tab, section labels, links and switches; suggested), S3
  Deep sand (#E6DCC8 page, cream #FBF7EE cards, olive), each with its
  matching icon (sand tile + fine edge). **Paul: leave the theme for now**
  (12 Nov 2026).

- **Still undecided** (from the player colour mock-ups,
  https://claude.ai/artifact/FU45FUnYLfGc2K41NUnt5q): the other
  "not like Apple" touches: olive as the app's own colour for the selected
  tab / links / switches, DM Mono numbers, tape-style progress, start
  times / done-by as a signature. Not built.

- **Type: Fraunces Soft** (Paul, 11 Nov 2026: the font feels "a bit too bold /
  strong"). Every title is Big Shoulders Black (900) in capitals. Options
  on https://claude.ai/artifact/HcvktcXpssM9FtFPNdqdFo: 1 today, 2 Big
  Shoulders Bold everywhere, 3 Display ExtraBold headings + Big Shoulders
  Text SemiBold row titles, 4 Display ExtraBold only for screen titles and
  section headings, row titles in SF semibold normal case, 5 Barlow
  Condensed (SemiBold headings, Medium rows). Suggested 4. Paul: keep
  proper case (not capitals); same link re-rendered in proper case
  (option 1 left in capitals to compare). **Paul picked 5** (11 Nov
  2026), on the branch: `App/Fonts/` now holds BarlowCondensed-SemiBold
  and -Medium (Google Fonts, OFL licence file) in place of Big Shoulders
  (removed); `Theme.big` = Barlow Condensed SemiBold (headings, screen
  titles, player title and time), new `Theme.title` = Barlow Condensed
  Medium (row titles, mini player, transcript lines); every title and
  heading in proper case (no `.uppercased()`), tab and screen titles too
  ("Up Next", "Library", "Episode notes"…); the iOS navigation bar titles
  use Barlow Condensed SemiBold. Labels stay DM Mono capitals, body SF.
  Then Paul held the build ("hold on build") and asked to see Fraunces
  Soft, New York and Bricolage Grotesque:
  https://claude.ai/artifact/RS87QNtkmwBu4QaRFnXYpu (Barlow beside them;
  New York is Apple's built-in serif, nothing to bundle). **Paul picked
  Fraunces (Soft)**, 11 Nov 2026, on the branch: `App/Fonts/` holds
  FrauncesSoft-SemiBold (headings, `Theme.big`, drawn at 92%) and
  FrauncesSoft-Medium (row titles, mini player, transcript lines,
  `Theme.title`, drawn at 85% as it's wider than the condensed faces the
  sizes were set for), static fonts made from Google Fonts' variable
  Fraunces with fontTools (SOFT 100, WONK 1, opsz 36 / 18, wght 600 /
  500; OFL, no reserved name); Barlow removed. Navigation bar titles use
  Fraunces Soft SemiBold. Proper case throughout. Went out in build 139.
- Library sections: decided, option 3 with each section's rule in its
  own colour (Paul, 11 Nov 2026); on the branch (see above). Earlier
  options on https://claude.ai/artifact/QVZuzJvu3x4p1cusBv2tbZ.

- **New Episodes ideas** (Paul, 11 Nov 2026: fresh ideas for the Library's
  New Episodes; 1 Inbox went in with the poster look, build 138). Mock-ups https://claude.ai/artifact/GR7UfPFs12b4Mpt8oZ1TyC
  next to today's carousel: 1 Inbox (Today / Yesterday / This week rows,
  swipe right Up Next, left played, "All caught up"), 2 Show circles like
  Stories (ringed show icons with counts, tap for that show's new ones),
  3 Triage deck (one big card, swipe right Up Next / left played / up
  play now), 4 Tape shelf (episodes as cassette spines in show colours,
  tap one to slide it out), 5 Morning digest (one front-page card, "6
  new since yesterday", one line each, Add the rest to Up Next). Waiting
  on Paul.
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
  mini player strip. Paul: "could work as a calmer and less busy
  version of the app". Refreshed on the same link: swipe actions are
  full-row blocks the row's own height and corners (right: To top / Up
  Next, green; left: Played, red); player reorganised for reach (top
  half = artwork printed in the show's colour with the title and
  chapter on it; line, play, skips, SPEED / TRIM / BOOST / SLEEP keys,
  transcript / chapters / Up Next all in the bottom half; no empty
  band). Artwork ideas: A Stamp (small tilted artwork on each row and
  the playing block), B Print (artwork as one ink in the show's colour
  with halftone, on big colour areas), C Slice (row strip widens into a
  slice of the artwork), D Gallery moments (artwork big only on show
  pages and player), E Wall of sleeves (Your shows as artwork tiles).
  Suggested A + B. Then real artwork in place (Paul asked to see one
  in situ): the playing show is Wastelanders: Star-Lord, its artwork
  cropped from Paul's Apple Podcasts screen recording (Apple's directory
  is blocked from the cloud machine), poster colour #7E3F3A picked from
  it; other shows stay made-up. Same link. **Paul picked A + B**
  (11 Nov 2026) with the stamps square, not tilted: a "Your pick: A +
  B" section on the same link shows Up Next (printed playing block,
  square stamp on every row, stamp in the mini player), the Library
  inbox and Your shows rows with stamps, and a show page (printed
  poster with the artwork as a square stamp beside the name). **Built,
  all screens at once** (Paul, 11 Nov 2026; see build 138 above).
  Icons (Paul, 11 Nov 2026: no emoji like the bell, "a flat 2d icon
  themed to the colour"): the mock-ups now use one set of flat line
  icons drawn in the surrounding text colour (bell, moon, AirPlay, trim,
  boost, transcript, chapters, tabs, sort…), shown on
  https://claude.ai/artifact/KA9BVpN9mzKdXxfNByQ4T1. The app itself
  already uses SF Symbols (flat, never emoji) in those spots; building
  the poster look would keep SF Symbols tinted to the colour, or swap in
  this set if Paul prefers its rounder style.
  App icon re-theme for the poster look (Paul: "the logo would need
  rethemeing"), same link: 1 Stamp (perforated postage stamp, rust print,
  sand cassette), 2 Printed cassette (sand cassette on halftone rust,
  off-register amber shadow), 3 Big P (Big Shoulders P on ink over the
  progress line), 4 Poster type (POD / DECK on amber), 5 Reels on the
  line (two reels joined by the progress line on rust); shown on dark /
  light home screens and at 60 / 40 / 29 pt next to today's olive
  cassette D. Suggested 1 or 5. Paul liked 2 and 5 ("evolve them a
  bit"): https://claude.ai/artifact/Mxf14F2Xft1No9W8NBdWNM with 2a
  Spoked (bigger cassette, spoked reels, no offset shadow), 2b Tape line
  (progress line across the cassette's bottom + amber print shadow), 2c
  Reversed (rust printed cassette on sand), 5a Tape path (tape running
  between the reels into the line), 5b Ink (reels + line on near-black),
  5c Big reel (one spool on the line), X Blend (printed cassette outline,
  spoked reels, line). Suggested 2b or X; 5b sharpest small. **Paul
  picked 2b** and asked if its shading matches the app: halftone dots,
  sand and the amber ad already do; the rust came from Star-Lord's
  artwork (not an app colour) and the hard offset shadow isn't used
  anywhere in the app (cards have soft shadows). Colourways of 2b next to
  the app's pieces: https://claude.ai/artifact/Qg7fe2hJ6WYjxc2ytCCbwy
  (rust offset / rust soft / olive offset / olive soft / ink soft / sand
  with olive cassette). Suggested olive + soft shadow. **Paul: go for olive + soft shadow**
  (11 Nov 2026): it is the app icon and the website's on the branch
  (UBDM; see the icon line at the top). The rest of the poster look is
  still waiting on Paul.
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
