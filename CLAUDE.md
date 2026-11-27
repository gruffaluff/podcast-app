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
screen. Icon (Paul, 14 Nov 2026, after build 154: A looked too like an
existing app): **"E · P card"**: the white P (Outfit ExtraBold) on an ink
card, a coral #EC6550 card tilted behind it, on a light warm-grey #EAE9E4
tile (`design/icon/icon_deck_ep.svg` / `.png`, rendered with Playwright
and the bundled Outfit font: app icon, `docs/icon.png`, IconPreview).
Before that (14 Nov 2026, build 154): **A "The deck"**:
three cards, blue #4C8DFF back-left, red #FF5A45 back-right, a white front
card with an ink edge and an ink play triangle, on the warm #EEEBE5 tile
(`design/icon/icon_deck_a.svg` / `.png` from `make_deck_icon_a.py`; it
also writes the app icon, `docs/icon.png` and the badge's IconPreview).
Before that (13 Nov 2026, with the Haar look): **"P1 Cassette in the
haar"**: Poddeck's cassette in deep blue (#2B4766) half lost behind two
bands of fog on a misty grey tile (`design/icon/icon_p1.svg` / `.png` from
`design/icon/make_haar_icon.py`: rsvg-convert + Pillow; it also writes the
app icon, `docs/icon.png` and the badge setting's IconPreview). Before that
(12 Nov 2026): **"W1b Warm white, fine edge"**: white
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

**Look: "Deck"** is now the only look (Paul, 17 Nov 2026: "Clear out
the old looks"; see build 168). Everything below about Haar, Native
warm, Deck 0, Poster and Middle ground is history.
**Look: "Haar"** (Paul, 13 Nov 2026: "work this as a version of Poddeck",
"stick with P1"; the app keeps the name Poddeck, Haar names the look, after
the cold sea fog off the North Sea). Mock-ups and a clickable prototype of
every screen: https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7 (page "v4 ·
Poddeck, Haar look"; earlier pages Nightcap, Tide, Tide Fog). The look:
a calm misty grey page (#D3D8DB) with three slow drifting bands of white
fog, tinted a little by the colour of what's playing (`FogBackdrop` in
`App/Haar.swift`); frosted white cards with a fine white edge
(`frostedCard`, used by `deckCard` / `posterCard`); soft charcoal ink
(#1F2328, muted #4B5259); the playing episode's deep colour as the only
colour (deep blue #2B4766 when nothing plays); titles in SF Rounded bold
(`Theme.big`, `Theme.serif`, `Theme.rounded`; Instrument Serif until build
153), everything else SF; plain text
and icons instead of button chrome wherever it's clear (Paul: "just
having text/icons in a lot of places … as long as it is clear"); no
visible scroll bars. It's a colour scheme (`ColourScheme.haar`), the new
default for a light iPhone (AUTO = Haar light / Night dark); Sand, Slate,
Clay and Night stay pickable. The fuller Haar navigation (the player as
home, Up next / Find / Library as layers with gestures, a three-button
dock Now · Library · Find, read-along with the word lit as it's spoken,
chapter timeline sheet, Library New inbox restyled, Find = search +
Discover with charts) comes in later phases (see "Haar rework" below).
Reverting: TestFlight keeps build 150 (Native warm) under Previous Builds
for 90 days, and commit a1cb37a (main before Haar) is its code.
Before that: **"Native warm"** (Paul, 11 Nov 2026, late, after build 142: "it
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
- **Ask before every build** (Paul, 19 Nov 2026, now Codemagic charges
  per minute): never merge to main (which starts a paid build) without
  asking Paul first and getting his yes for that build, even if an
  earlier message said "build". Pushing to the branch and the free
  GitHub check are fine.
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
  speakers; Paul confirmed again 13 Nov 2026: "not worth the hassle").
  Later: smart lists, folders, extra Podcasting 2.0 tags.
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

### Ad skipping (switched off, Paul 16 Nov 2026: see build 166; `AdFeature`)
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

## Done in build 150 (13 Nov 2026, PR #68; Paul: "build")

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
  so the whole card slides, like Up Next.

- **Options sheet tidied** (Paul's build 149 screenshot, 13 Nov 2026:
  blue icons and + didn't fit, the see-through glass was too cloudy, and
  the sleep timer was hidden until you swiped up): `PlayerOptionsSheet`
  is now one compact layout sized exactly to its contents
  (`presentationDetents([.height(measured)])`), so everything shows at
  once; solid warm page (`presentationBackground(Theme.background)`) with
  white cards; icons, − / + and Done in ink, the chosen quick speed and
  switches in the accent; no footers; "+5" beside the sleep timer while
  it runs.

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
  rows were already one line each.

- **Sheets from inside the player washed out** (Paul's screenshot, 13
  Nov 2026: Share a clip's Cancel / Share and the Include audio / Link to
  the moment labels were pale on pale). The player paints its text and
  keys in paper, and sheets opened from inside it (Share a clip from the
  transcript panel, the full Chapters list from the chapters panel) took
  that on. They now reset to ink and the accent (`normalColours()` in
  Deck.swift).

- **Playing bars calmer** (Paul's recording, 13 Nov 2026: the little
  red bars on the playing card were "a bit wild", jumping about). They
  were a repeating animation that every redraw of the row (its progress
  line ticks twice a second) restarted. `PlayingBars` now follows the
  clock: each bar a slow, smooth wave of its own (1.1–1.7 s, 4–9 pt),
  so redraws can't jolt them; still and level while paused.


## Done in build 151: Haar rework (13 Nov 2026, PR #69; Paul: "Build")

Paul, 13 Nov 2026: "let's work on restyling it all and bringing over
into live", "stick with P1". Every Poddeck feature stays; only the look
and the way round the app change. Prototype with every screen (Poddeck
features folded in): https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7.
Built in phases so each one can be tried on the phone:
1. **Look** (this branch, first PR): Haar colour scheme as the default,
   fog page behind every screen, frosted cards, Instrument Serif titles,
   P1 icon. Every screen picks it up through `Theme`, `deckCard`,
   `posterCard`, `haarPage()` and `Theme.rowBackground`.
2. **Player as home**: the player is the first screen; big artwork that
   shrinks to the corner for read-along (line now in the serif, each word
   lit as it's spoken, chapter breaks as a rule with the title); a
   waveform-style progress line with chapter dots and faded ad sections;
   chapter pill "4/6 · title" with ‹ › under it, opening the chapter
   timeline sheet; a soft card when a new chapter starts; AirPlay and ⋯
   (episode options) at the top; Up next stacked under the player.
3. **Navigation**: iOS tab bar replaced by the floating dock Now ·
   Library · Find; swipe up for Up next, down for Find, left for Library,
   back the way you came; Find = search + Discover (new to you, UK charts
   with serif rank numbers and movement, categories as text tabs).
4. **Library and settings**: New inbox (Today / Yesterday / This week),
   Carry on with rings, shows as an artwork grid (ranked first), shelves
   (Downloads, Saved clips, History, Stats, Finished); show page as a
   sheet with Episodes / Settings; settings with the fog slider and
   "tint the mist with each show".
Not decided yet: Dusk (a darker fog for evenings; Night stays the dark
scheme for now).

Phases 2-4 built the same evening (Paul, 13 Nov 2026: "get all phases
worked through while I do dinner and bedtime and then we can build and
test it all in one go"), same branch / PR #69, not merged. Built without a
compiler (GitHub's check compiles it). Only in the Haar look: every other
scheme (Sand, Slate, Clay, Night, so also AUTO in dark mode) keeps iOS's
tab bar and the Native warm screens (`RootView.content`).
- Player as home: `App/HaarPlayer.swift` (`HaarNowView`). Top: AirPlay,
  "Playing on …" when not the iPhone, ⋯ menu (episode notes, go to show,
  download / remove / stop, transcribe now / stop / read along, share
  link, mark played). Big artwork + serif title (tap the title for notes,
  the show line for the show); tap the artwork or "Read along" and it
  shrinks beside the title while `HaarReadAlong` fills the space (line
  now in the serif, words lit across the line's time, interpolated
  between the player's twice-a-second updates; chapter rules; tap a line
  to play from it; hold for Share a clip / Copy; Back to now). Chapter
  pill "‹ 4/6 · title ›" (tap for `ChaptersView` as a sheet), a frosted
  chapter card floats in for 3 s when a new chapter starts while playing.
  `HaarWave`: 64 bars (shape made up from the episode ID, not the real
  sound), played in ink, ads fainter, chapter dots under; drag anywhere,
  moves by how far the finger travels, lower = finer, bubble, Undo for 2
  min+ jumps (no "start from the play point" rule here: a touch can't
  jump). Times + "ends 19:42", skip / play / skip, the volume (only on
  taller screens), Options (`PlayerOptionsSheet`, summary like "1.2× ·
  Trim") · Read along · Chapters as plain words, `HaarUpNextStack` (next
  episode as the top of a small card stack; tap for Up next). Nothing
  playing: the top of Up Next big with Play, or "Nothing playing" + Find
  something. No episode notes on the page (⋯ → Episode notes).
- Navigation: `App/HaarRoot.swift`. The old full-screen player and the
  mini player aren't used in Haar ("open the player" goes home). Library
  slides in from the right, Find drops from the top (each made the first
  time, then kept, so they keep their place); Up next is `UpNextSheet`
  (medium / large). Swipes on home: up Up next, down Find, left Library
  (the waveform, read-along and buttons keep their own touches). Back:
  the dock, Find's handle (swipe up), Up next swipes down. No swipe back
  from Library (it would fight the show page's own back swipe). `HaarDock`
  floats at the bottom (Now · Library · Find, dot under the current one,
  a play / pause on the left when away from Now). Layers get bottom
  padding so their last rows clear the dock; Undo sits 84 pt up.
  `tab` is 0 Now, 1 Library, 2 Find in Haar.
- Find: `App/HaarFind.swift` (`HaarFindView`). One box: Your shows,
  Episodes (tap plays), Said in your episodes (transcript search), New
  shows (Apple's directory). Empty: recent searches, New to you (like a
  followed show), the chart with category words (All, News, Comedy…)
  and `HaarChartRow` (big serif rank, ▲ n / ▼ n / NEW / – under it, Follow
  as a word). Movement: `ChartHistory` keeps each chart's ranks per day
  in UserDefaults ("chartHistory.<uk or genre id>"); the first day shows
  no marks.
- Library: `App/HaarLibrary.swift` (`HaarLibrarySections`, used by
  LibraryView in Haar). New grouped Today / Yesterday / This week (one
  week, as before; artwork plays, row opens the episode page, + adds to
  Up next, ✓ played with Undo; Add all to Up next / Mark all played),
  Carry on with a ring round play, Your shows as a 3-across artwork grid
  (Top shows first with their rank in the corner, new-this-week count),
  shelves: Downloads (`StorageView`), Saved clips (`HaarSavedClipsView`),
  History, Stats. The gear (top right) opens the settings screen
  (`TopPriorityView`; in Haar there's no Up Next tab to open it from).
  Show pages are still pushed, not a sheet with Episodes / Settings tabs
  (the push keeps "go to show" and the back swipe working; the settings
  key on the show page covers settings).
- Settings → Colours (Haar only): Fog slider (light to thick, "haarFog",
  0–1.4, default 1) and "Tint the mist with each show" ("haarTint",
  default on), read by `FogBackdrop`. Not synced (this iPhone).
- Opened up for reuse: `RoutePicker`, `PlayerOptionsSheet`,
  `SystemVolumeSlider` (NowPlayingView.swift), `TranscriptResultRow`,
  `ClipRow` (SearchView.swift).
- To check on the phone: swipes on home vs scrubbing / read-along
  scrolling, the dock over the last rows, the artwork size on a smaller
  iPhone, word lighting timing, the chart marks from the second day, fog
  cost (the page fog is drawn under each layer).

## Done in build 152 (13 Nov 2026, PR #70; Paul: "add in everything outstanding and build")

- **Matching the Haar prototype's last row** (Paul, 13 Nov 2026: "not
  looking or flowing and operating as well as the mock up",
  https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7, page v4, row "Real
  example: Elis James and John Robins, #592"). Gap list given to Paul in
  three batches: 1 colour + Now screen (show colour as the accent and
  page mist, filled play circle with speed / sleep beside it, bigger
  rounder artwork, show name above the title, chapter in the time row,
  Up next stack with meta line), 2 motion (Up next and Read along as
  in-place morphs, translucent Library / Find layers, rounded sheets
  above the dock, top toasts), 3 Library / show page / chapters
  (timeline, Stop at chapter end, Skip this chapter, empty states).
  Decided so far (Paul, 13 Nov 2026): keep the Your shows badge fix
  (rank beside the name, "n new" pill), not the prototype's badges on
  the art; keep a volume slider; keep the ending time if it fits.
  Volume and ending time (mock-ups
  https://claude.ai/artifact/Tv46pEoExxAgwruXE6MYtr): **Paul picked
  volume A** (a thin line under the transport, the width of the progress
  line, small speaker icons each end, dot only while touched; hidden on
  the smallest iPhones) **and ending time B** (tap the time left to swap
  "−41:48" for "ends 21:42" and back). Paul: "add in everything
  outstanding and build" (13 Nov 2026). All three batches built the same
  evening by four helpers in parallel, merged on this branch:
  - Colour: the page mist mixes 24% of the show's colour (was 12%), its
    glow 16%; Undo is a dark toast near the top in Haar (`UndoBar`
    toast, `RootView` overlay).
  - Now (`App/HaarPlayer.swift`): AirPlay · grab handle (tap = Find) · ⋯
    (adds "Speed and sound…" = `PlayerOptionsSheet`, and Chapters);
    artwork up to 280 pt radius 46 with a Read along pill when words are
    ready; show name in accent caps above the serif title (33, or 25 over
    44 characters); plain line; time row with `HaarChapterControl` in the
    middle (opens the chapters sheet even with none) and time left that
    swaps to "ends HH:MM" on tap ("haarShowEnds"); `HaarTransport`:
    speed cycler 1 / 1.3 / 1.5 / 2×, skips, a 70 pt play circle in the
    accent, sleep moon cycling Off / 15 / 30 / 45 / 60 / End;
    `HaarVolumeLine` (hidden at 680 pt tall or less); the Up next stack
    (`App/HaarUpNext.swift`, 76 pt frosted card, two peeking above, "47
    min left · skips 2 ads · words ready"); ad as a dark pill at the top;
    chapter flash pill. Gone: the Options words row, chapter pill row,
    "ends" middle text, "Playing on", the big ad block.
  - Read along: the same screen morphs (0.7 s): artwork to a 60 pt
    corner square, ⌄ back, words rise in; `HaarWordsOnTheWay` empty state
    ("Words are on their way.", %, Transcribe now); speaker names, the
    current word in the accent, chapter rules in italic serif, Make a
    clip.
  - Up next (`HaarUpNextList`): in place, not a sheet; cards fly in;
    "clears by" time; long-press reorder; swipe right Play next / left
    Played with Undo; rank pills; the episode playing isn't listed; Keep
    playing toggle at the end.
  - Navigation (`HaarRoot`): swipes start at 12 pt and fire at 48;
    Library slides from the right and Find from the top on the 0.7 s
    curve over a see-through layer (Library still draws its own fog, so
    it's solid); dock 224×58 with one sliding dot, no play button.
  - Library (`HaarLibrary.swift`, `LibraryView`): serif "Library" 44
    header with + and sliders, summary "9 shows · 3 ranked · 26 unplayed",
    caps section labels, New as one card by day with Clear all, Carry on
    rings on the left in the show's colour, tiles radius 24 (rank and "n
    new" pill as Paul chose), Shelves as one card with detail lines and a
    new Finished list.
  - Show page (`HaarShow.swift`, `HaarShowParts.swift`): its own Haar
    page in a translucent radius-36 sheet: 88 pt artwork, serif 32 name,
    "Twice a week · 592 episodes", Following ✓ / ▶ Play latest, Episodes /
    Settings tabs under the header, episodes in one card with NEW / IN UP
    NEXT / PLAYED labels (tap plays, swipes, menu), Settings with the
    Top priority ↑ #n ↓, switches, and word choices for where new
    episodes go, intro / outro skip, speed, keep downloads. Not on it
    (yet): searching the show's episodes and Select mode. Older values
    outside the word choices show nothing underlined.
  - Chapters (`HaarChapters.swift`, `HaarChaptersSheet`): timeline sheet
    (rail, nodes, current in serif accent with minutes left), "Chapters
    arrive with the words." when there are none, From the show / Auto
    words, Stop at chapter end (`PlayerModel.setStopAtChapterEnd`,
    fades and pauses at the chapter's end) and Skip this chapter.

- **Haar show page, swipe back, plain line** (Paul, 13 Nov 2026, after
  build 151: "let's work the show page and swipe back (if valid)"; "the
  waveform shape doesn't need to mimic the real sound … simplify this
  line like Poddeck had"). On the branch, not built:
  - Show pages open as a sheet over wherever you are
    (`HaarShowSheet` in `App/HaarShow.swift`, from `store.showSheet`,
    presented by `HaarRoot`): Episodes / Settings as two words at the
    top with Done; Episodes is the usual `ShowView` (kept alive so it
    keeps its place), Settings is `ShowSettingsView(embedded: true)`; the
    show page's settings key and "Show settings" switch to the Settings
    page (`\.openShowSettings`). Opened from Library's grid, Find's
    "Your shows", the player's ⋯ Go to show / show name and an episode
    page's show (`revealShow` → HaarRoot; no tab switch, no push). An
    episode page opened from the sheet shows over it (the root view's
    episode sheet stands aside while a show sheet is up).
  - Swipe right on Library's first page goes back to Now (`SwipeRight`,
    a pan that only starts when moving right, so scrolling isn't
    touched; pages pushed on Library, e.g. History, keep iOS's back
    swipe). Valid now that shows no longer push inside Library.
  - The waveform is gone: `HaarScrubLine` is a plain line like
    Poddeck's (5 pt, split by 3 pt gaps at chapters, played in ink,
    ahead faded, ads paler, an ink dot at the play point; thicker with a
    bigger dot while dragging). Same drag rules, bubble and Undo.
  - Your shows grid (Paul's build 151 screenshot: the counters were lost
    on the artwork and the 1–4 rank badges didn't work): the rank is off
    the artwork, a serif number beside the show's name; the new count is
    a solid dark pill with a white edge, "1 new", in the top corner
    (`HaarShowTile`).
  - Last rows stuck behind the dock (Paul's build 151 screenshot:
    Library's Shelves couldn't scroll clear): Library and Find got their
    room as safe-area padding round their navigation stacks, which didn't
    reach the lists inside; now a bottom scroll margin of dock + 12 pt
    (`contentMargins` in `HaarRoot`), which also covers pages pushed on
    them (History, Stats…).

## Done in build 153 (13 Nov 2026, PR #71; Paul: "Rounded and all your picks as we mocked up. Build")

Paul's notes after build 152 (screenshots of the show Settings tab, the
Now screen and Up next's Keep playing row): scrolling "not the smoothest
… low framerate"; Settings word choices odd all left-aligned; not sure
about the sliding layers; iOS's own volume bar popping up at the side;
title font "nice but too elegant"; menus like Keep playing were plain text
in the mock-up ("replicate throughout"); the New box looks odd; other ways
to show Your shows. Options:
https://claude.ai/artifact/BPRLRv99kWnq74Hr3aKdKp, then SF Rounded with the
suggested picks on every screen (with Carry on, as Paul asked):
https://claude.ai/artifact/32Yjrqvdz3igPu7m1wHoFN. **Paul: Rounded and
all the suggested picks.**
- Smoother scrolling: the fog is soft gradients (no `.blur`), only the
  root fog drifts (`haarFogBehind`), cards have no live material.
- Plain-text menu rows (Keep playing, shelves, show settings;
  `HaarMenuHairline`), no white cards.
- iOS's volume bar kept away (`HaarVolumeHUDHider` in `HaarRoot`; check
  on the phone).
- Titles in SF Rounded bold (`Theme.rounded`; `Theme.big` at 88%,
  `Theme.serif` at 86% of the serif sizes; nav bar large titles too).
  Chapter rules in read-along no longer italic. Instrument Serif's file
  is still bundled but unused.
- Now / Library / Find cross-fade in place in 0.2 s (`HaarRoot.fade`);
  they slid before. Up next and Read along keep their 0.7 s morph.
- Show settings choices spread evenly across the page, underline under
  each share (`HaarShowWord(fills:)`, `HaarShowChoice`).
- Library: New as a plain list (no card, "New · n", faint day labels);
  Carry on as a plain list ("Carry on · n", total time left, ring in the
  show's colour on the left, show label, title, time left, artwork on the
  right); Your shows as a plain list (`HaarShowLine`: 46 pt artwork, rank
  as a rounded number before the name, where new episodes go, "n new"
  pill); the grid (`HaarShowTile`) and the card (`haarGroupCard`) are
  gone. The old Carry on / Your shows card-height note is dropped (those
  cards aren't in the Haar Library).
- Episode keys on Now (Paul, 13 Nov 2026: "still like to see download,
  transcribe and mark as played somewhere"; options
  https://claude.ai/artifact/X49sL6x7gvwQoJMX3dqhed, **Paul picked D**,
  evenly spread, filling as they progress): three words spread evenly
  under the title (`HaarNowView.episodeKeys`, `HaarKeyWord`): Download /
  "Downloading 40%" (fills with the accent left to right, tap to stop) /
  ✓ Downloaded (grey, tap to remove with a confirm); Transcribe /
  "Transcribing 62%" (fills, tap to stop) / ✓ Words ready (tap to read
  along); Mark played (with Undo). Still also in ⋯.
- Show page fuller (Paul, 13 Nov 2026, build 152 screenshot: the show
  sheet looked empty with one unplayed episode; options
  https://claude.ai/artifact/TQpmnvsJ7QjSMhXdm3JwY9, **Paul picked C
  "Search and months"**): a search box for the show's episodes (titles
  and notes, every word typed) at the top of Episodes; on Unplayed,
  "That's everything unplayed." then the most recent 60 played episodes
  grouped by month (newest first; "Older episodes are under All" beyond
  that) (`HaarShowEpisodes`). All is unchanged.
- Find on the fog page like Library (`.haarPage()`; Paul: "so white it
  stands out"; it only had the pale see-through layer).
- Sleep moon no longer jumps when the minutes appear: the moon stays put
  and "15M" sits under it as an overlay (`HaarTransport.sleepButton`).

## Done in build 154 (14 Nov 2026, PR #72; Paul: "get a full build going so I can test when I'm home")


- **Deck redesign** (Paul, 14 Nov 2026: "I love it"; prototype
  https://claude.ai/artifact/CC3pxxR1XwBGtnp13xAdbB, file and build notes in
  `design/deck/`; mock-ups page "v10" on
  https://claude.ai/artifact/MyaR1XmhaAy6Vf17WGv2i7). Up next is a deck of
  episode cards (top card = the one playing; swipe left Played, right a
  little "Next in line", right far "To the bottom"; tap the stack to fan
  it out), Shows a deck of show cards, Find = search + charts; a floating
  white pill Up next · Shows · Find, a mini player on Shows / Find, the
  full player as a gradient in the show's colour, Settings behind a gear.
  Outfit type (bundled, OFL), warm page #EEEBE5, white cards. Every
  feature stays; `QueueEngine` rules don't change. Paul's answers: carry
  on from the PR #72 branch (its fixes go out with Deck), plain warm page
  (no fog), icon A "The deck", build the Layout setting now. Deck is the
  new default (AUTO = Deck / Deck night); Haar, Sand, Slate, Clay and
  Night stay pickable with their old screens. Phase 1 (on the branch):
  `ColourScheme.deck` / `.deckNight`, `Theme.isDeck`, `Theme.outfit`,
  `App/Fonts/Outfit-*.ttf`, `DeckRoot` (pill, mini player, pages).
  Then four helpers in parallel, merged on the branch, compiled first
  time on GitHub's check:
  - Up next (`DeckUpNext*.swift`): header with the deck mark, "n · done
    by", gear (Settings sheet); top card (`DeckTopCard`) with swipes
    (left Played, right 90–200 Next in line, past 200 To the bottom,
    haptics, stamps), Skip ad chip; four stacked edges with start times;
    empty deck card; the fan (`DeckUpNextFan`: List + onMove, pull down
    past 110 to close, row swipes, Keep playing). Fan cards sit 6 pt
    apart rather than overlapping (iOS's drag-to-reorder stays safe).
    Next in line / To the bottom reorder `store.queue` as hand placed and
    load the new top in the player.
  - Layout setting (`DeckLayout.swift`, "deckLayout": Standard / Big
    buttons / Calm / Read along; only the top card changes;
    `DeckLayoutView` in Settings → Look).
  - Player (`DeckPlayer*.swift`): gradient in the show's colour, ⌄ /
    UP NEXT · n or PLAYING ON / ⋯, artwork that shrinks for Read along
    (`DeckReadAlong`), chapter pill + Skip ad, white scrub line (Haar
    drag rules, Undo), transport, volume on tall screens, Options ·
    Read along · Chapters · AirPlay; `DeckPlayerChaptersSheet`.
  - Shows (`DeckShows*.swift`, `DeckShowDeck.swift`): show deck (new
    first, then Top rank, then A–Z), All your shows tiles, New sheet;
    `DeckShowPage` (pills, Top / Bottom / Nowhere, episodes with keys and
    two-distance swipes via `deckShowSwipe`, ⋯ menu); `DeckEpisodePage`
    (shown by EpisodeNotesView in Deck).
  - Find (`DeckFind.swift`): search sections, charts with movement,
    `DeckFollowSheet` (where new episodes go, Alerts, Download the
    newest; the newest is dealt in on Done); Settings
    (`DeckSettings.swift`: every Shows-screen setting in grouped cards,
    `DeckPriorityView`).
  - Not done: Select mode on the show page; ShowPreviewView still uses
    the old follow button. To check on the phone: swipe distances (90 /
    200 pt), pull-down to close the fan, dragging in the fan, the pill
    over last rows, mini player clearance, Read along timing, Deck night,
    smaller iPhones.

- **After build 153** (Paul, 14 Nov 2026), on the branch, not built:
  - Now / Library / Find switch instantly (no fade).
  - Up next closes by pulling its list down from the top (it only took
    the swipe on its heading).
  - Now's transcript word says "Read along" when the words are ready
    (was "Words ready"); the Read along pill on the artwork is gone; no
    ticks on done words (Downloaded / Read along just go grey).
  - Smoother motion: the 0.7 s curves are 0.4 s smooth moves
    (`HaarNowView.morph` / `rise`, `HaarRoot.slide`); Up next's cards fade
    in together instead of flying up one by one (the artwork lagged
    behind its card).
  - Show page on the app's grey page (`Theme.background`), rows the same
    grey with hairlines, no white card edge (Paul: "quite white … not on
    theme").
  - Mini player and episode page (Paul, 14 Nov 2026: "your picks" from
    https://claude.ai/artifact/NVL7stWLG81ydyDosUnihH):
    - **B, slim bar above the dock** over Library and Find while
      something is on (`HaarMiniBar` in HaarRoot.swift): artwork, title,
      show · minutes left, play / pause, skip forward, a thin progress
      line along its foot; tap it to go back to Now. Layers' bottom room
      grows to clear it.
    - **A, words like Now** on the episode page in Haar
      (`HaarEpisodeWords` in EpisodeNotesView.swift): "2nd in Up next"
      (opens Up next) / "Add to Up next" / "Played" (tap for unplayed);
      Download / "Downloading 40%" / Downloaded (remove with a confirm);
      Transcribe / "Transcribing 62%" / Read along (opens the transcript).
      The white status cards (`EpisodeStatusRows`) and DL / TX letters
      stay for the other looks; the notes are plain text in Haar.

## Done in build 155 (14 Nov 2026, PR #73; Paul: "work on the not dones yet and get it all in")

- App icon "E · P card" (see the icon line at the top; Paul: A was too
  like an existing app).
- Select mode on the Deck show page (`DeckShowEpisodeList`): Select /
  Done beside Unplayed · All · All played; tap episodes to tick them;
  a bar with "n selected", Select all / none, Played, Unplayed and Up next
  (oldest first), all with Undo (`DeckShowSelectBar`, `DeckShowSelectRow`).
- Show previews (Find, charts) follow through the Deck follow sheet in
  Deck (`ShowPreviewView` uses `DeckFollower` / `DeckFollowSheet`; the
  old settings sheet stays for the other looks); Open show goes to the
  Deck show page.

## Done in build 156 (14 Nov 2026, PR #74; Paul: "Let's build here as I can't use it properly without")

Paul's notes after build 155, all in Deck:
- **Shorter swipe down to close**: the player closes past 60 pt (was
  110) or a light flick; the fanned-out Up next past 60 pt.
- **Tab pill**: switching tabs is instant (no animation carries the ink
  capsule across); a fine ink edge, a deeper shadow and a soft fade of
  the page colour behind the bottom of the screen, so it stands off
  white cards scrolling under it (`DeckTabPill`, `DeckRoot.bottomFade`).
- **Last stacked card** under Up next's top card is only as tall as its
  row (62 pt; it was a 120 pt mostly empty card).
- **"Unplayed" no longer cut short** on the show page: EPISODES on its
  own line, the Unplayed / All pills never squeezed, Select and All
  played on the right.
- **Show deck**: only shows with new episodes (Top rank, then A–Z);
  "All caught up" card when none (`DeckShowsView.newDeck`). Dots only up
  to 6 shows and darker, "3 of 12" in ink beyond that.
- **All your shows**: two across down the page, each tile the artwork
  edge to edge with the name in white over a dark fade and "n new" as a
  pill in the corner (`DeckAllShowsRow`, `DeckShowTile`).
- **Up next fan**: the ≡ handle centred on each card.
- **Opening the player from Up next**: the black flash was the player
  opening with nothing loaded (e.g. just after opening the app) and
  closing itself. The top card now loads its episode first, ready but
  not playing (`PlayerModel.play(_:autoplay: false)`); the whole top
  card opens the player; the episode artwork's colour is measured ahead.
- **Artwork / transcript switch** on Up next's top card: a round key in
  the picture's corner swaps the artwork for the line being said
  (white on the show's colour; "No words for this episode yet…" when
  there's none). Remembered as "deckTopWords" (this iPhone).
- **No internet bar**: cloud-with-a-line icon, rounder, lined up with
  the cards (16 pt) in Deck.
- "New since you last looked" triage: Paul said go (15 Nov 2026); see
  the queue.

## Done in build 157 (15 Nov 2026, PR #75; Paul: "Build")

- **Last stacked card, again** (Paul, 14 Nov 2026, build 156 screenshot:
  "some rendering issues with the cards"): the 62 pt last card was
  shorter than the bit of the card above showing below the 48 pt step
  (72 pt), so that card's foot poked out under it as a second edge. Last
  card now 84 pt (`DeckEdgeCard`).
- **Swipe left / right on the tab pill** (Paul, 14 Nov 2026, FNB: "add
  swipe left and right on the menu bar"): swiping along the Up next ·
  Shows · Find pill moves to the next / previous tab (`DeckTabPill`).
- **Alignment pass** (Paul, 14 Nov 2026, FNB, screenshot of the Deck
  player's chapter row "‹ 4/14 · Best Among Imperfect Options ›": "not
  center aligned. Can we make sure alignment throughout is right"): the
  ‹ pill › row sits left of centre (the pill grows with its title, so the
  arrows aren't evenly placed round the middle). Plan: arrows in fixed
  slots at each side, pill centred between them and shrinking long titles
  (`DeckPlayer*` chapter row); then check every Deck screen for things
  that should be centred or lined up (player rows, top card, sheets, the
  pill, headers) and fix them in the same build.
- **Undo bar lost on the page** (Paul, 15 Nov 2026, FNB: "the undo pop
  up is the same colour as the background so gets lost a bit. Make it
  clearer"): in Deck the Undo bar uses the page colour. Plan: a dark ink
  bar with white text and a bold UNDO, a soft shadow, the same 16 pt
  edges as the cards (`UndoBar` in Deck).
- **Pull down to close the player: janky and hit and miss** (Paul, 15 Nov
  2026, screen recording). The drag was measured in the player's own
  space while the player moved with the finger, so every movement counted
  twice and it juddered (the same fault the show page swipes had in build
  140); on letting go iOS's own close animation started from wherever the
  player was, so it jumped. Now measured against the screen, follows the
  finger once it's clearly going down, and on release past 60 pt or a
  light flick the player slides away itself and then closes with no
  second animation (`DeckPlayerView.closeSwipe`, `slideAwayAndClose`).
 
- **Up next top card: Transcribe now, download key, no flash** (Paul, 15
  Nov 2026: loves the transcript key; "yes" to Transcribe now in the
  empty space; "couldn't we also get a DL button on the other side";
  recording: the "no words yet" note flashed up before the transcript).
  With the words on and none yet: "No words for this episode yet." and a
  white Transcribe now key; while on its way "Downloading first 40%" /
  "Transcribing 62%" with a bar and Stop; the words appear by themselves
  when ready. The lines now load the moment the key is tapped (they
  loaded a beat later, so the note flashed first) and nothing shows while
  a ready transcript loads. A round download key in the picture's bottom
  left: arrow to download, a filling ring while it downloads (tap stops
  it), filled when on the phone (tap to remove, with a check)
  (`DeckTopDownloadKey`, `DeckTopWords.Status / Download`). 
- **Undo just above the tab pill** (Paul, 15 Nov 2026, screenshot: the
  Undo bar floated over the stacked cards): in Deck it sits 10 pt above
  the pill, and above the mini player on Shows / Find while something is
  on (`RootView.deckToastLift`).
- **Swipe up to open Up next** (Paul, 15 Nov 2026: "can swipe up on the
  up next queue open it"): swiping up on the deck (top card or the cards
  under it) fans out the whole list, like tapping the cards under it
  (`DeckStack.swipeUp`).
- **Up next list: time and DL / TX lined up** (Paul, 15 Nov 2026,
  screenshot): the start time now sits on the show line (same baseline)
  and DL / TX beside the title's first line, instead of a separate column
  floating between them (`DeckUpNextFan` row `titles`).
- **Header mark updated** (Paul, 15 Nov 2026, screenshot of the Up next
  header: "icon update"): the little mark beside "Poddeck" was still icon
  A's three cards; now the E · P card (white P on ink, coral card tilted
  behind), 30 pt (`DeckMark`).
- **Show page pills lined up** (Paul, 15 Nov 2026, screenshot:
  "alignment and spacing"): Following / Alerts / Settings are three equal
  pills filling the row, the same widths and gaps as Top / Bottom /
  Nowhere below (`DeckShowPagePills`).
- **Show deck swipe feels like nothing happens** (Paul, 15 Nov 2026:
  "maybe it just needs to be a row you swipe along"). Suggested a
  sideways row of show cards with the next one peeking in from the right,
  following the finger and snapping to each card. **Paul: "build it that
  way"** (15 Nov 2026): done built: `DeckShowStack` is a
  sideways `ScrollView` of `DeckShowCard`s (screen width less 56 pt, 12 pt
  apart, settling on each card with `.viewAligned`), the ‹ › keys and dots
  still under it; the fanned back cards are gone.
- **Sort for All your shows?** (Paul, 15 Nov 2026: "what order … do we
  have the sort order button"): today the same order as the cards (new
  first, Top rank, A–Z); no sort key in Deck. Offered a ⇅ key beside the
  label (New first / Name A–Z / Latest episode / Top ranking). **Paul:
  "add the sort button"** (15 Nov 2026): built: a small
  ⇅ menu on the right of the ALL YOUR SHOWS label showing the chosen order
  (New first, the default / Name A–Z / Latest episode / Top ranking, then
  A–Z), kept on this iPhone as "deckShowsSort" (`DeckShowsSort`).
- **Missing from the Deck look** (Paul asked 15 Nov 2026 "what else are we
  missing"; checked the code): Carry on (started, unfinished episodes) has
  no home; Saved clips can't be reached; Add a show by pasting a link (RSS,
  private / Patreon feeds, Apple Podcasts links) isn't in Find; the show's
  own settings (speed, skip intro / outro, keep downloads) open the older
  look's sheet. Asked Paul which to do. **Paul: "add all 4"** (15 Nov
  2026), built:
  - Carry on on the Shows tab above the show cards: up to three started
    episodes (not the one playing) as slim white cards, the artwork in a
    ring that fills as far as you've got, title, "show · 34m left", a
    play key; tap the card for the episode page (`DeckCarryOnSection`).
  - Saved clips: a row in Settings → Your listening, under Downloads
    (opens `HaarSavedClipsView`).
  - Paste a link into Find (a feed, a private Patreon / Supercast feed,
    or an Apple Podcasts link; "feed://" too): a card "A show's feed
    link" with Follow this show, then the Deck follow sheet; Following ·
    Open show after (`DeckFindLink`, `DeckFeedLinkCard`,
    `DeckFollower.follow(link:)`). The search waits while it's a link.
  - The show page's Settings pill opens `DeckShowSettingsSheet`: grouped
    white cards like Settings: Download new episodes, Alert me, Keep
    downloads; Speed / Skip intro / Skip outro for this show; Older
    episodes (Add all to Up next, Mark older played with Undo).
- **Go for all** (Paul, 15 Nov 2026: "yes that's good. Go for all"):
  - Undo bar in Deck: near-black (#1C1B1A) with white words and a white
    Undo pill, 52 pt, soft shadow (`UndoBar.deckBar`).
  - Swipe along the tab pill: right for the next tab, left for the one
    before, instantly, with a tick (`DeckTabPill.swipe`).
  - Alignment: the player's chapter row has its ‹ › in fixed 44 pt slots
    at each edge and the pill centred between them (long titles shrink a
    little, then cut off); during an ad Skip ad / Play ad takes the
    pill's place (`DeckChapterRow`). Other Deck rows checked in the code.
  - "New since you last looked": the Shows tab's New · n opens a catch-up,
    one big card at a time, oldest first: swipe right Play next, left Skip
    (marked played), or keys Skip / + Up next (Keep when already queued) /
    Play next; "Already 3rd in Up next" on the card; Keep the rest / Skip
    the rest; "All caught up". Each one dealt with is remembered on this
    iPhone ("deckTriaged", newest 400), and the pill counts only those not
    looked at yet. "List" switches to the week's list as before with Add
    all / Mark all played (`DeckTriage`, `DeckTriageCard`,
    `DeckShowsNewSheet`).
- **Show preview in the Deck look** (Paul, 15 Nov 2026, screenshot of
  The News Agents from Find: "the show screen via Find is still the old
  one"): shows you don't follow yet now open like a followed show's page:
  white header card (104 pt artwork, name, "publisher · genre · n
  episodes"), one wide ink Follow pill (Try again if it failed; once
  followed "Following · Open show" in the show's colour, opening the Deck
  show page), the description, then LATEST EPISODES · n in all as white
  cards (date · length, title with two lines' room, two lines of notes,
  tap for all of them). The printed poster header stays for the other
  looks (`DeckShowPreview`, `ShowPreviewView.deckBody`).

## Done in build 158 (15 Nov 2026, PR #76; Paul: "Build")

- **Bottom stacked card filled in** (Paul, 15 Nov 2026, build 157
  screenshot: the last card under Up next's top card had empty space;
  "either expand the info into the space or tighten up. I'd suggest more
  info"): the bottom card now has a third line, "9 Nov · 52m" (or "12m
  left" once started), and the DL / TX letters under its start time
  (`DeckEdgeCard.detail`). The cards above it keep two lines (only their
  top shows).

- **Undo puts the card back on top** (Paul, 15 Nov 2026: undoing a swipe
  on Up next's top card put the episode back in the queue, but the next
  one stayed on top). Played (left swipe) and Next in line / To the
  bottom (right swipes) on the episode that's on now: Undo also loads it
  back in the player where it was, playing if it was
  (`DeckQueueMoves.comesBackOnTop`).

- **After build 157, Paul's list** (15 Nov 2026: "get working on 1-7"
  from the ideas list, plus three notes). Four helpers in
  parallel, merged on the branch:
  - **No swipe on the tab pill** (Paul: "unneeded"): removed; taps only.
  - **Pull down to close the player, lighter** (Paul: "you have to put a
    real motion in"): starts after 4 pt, closes past 36 pt, on a flick
    (300 pt/s) or a predicted 90 pt (`DeckPlayerView.closeSwipe`).
  - **Artwork shrink / grow smooth** (Paul: "a little unsmooth"): one
    picture drawn over the player that slides and resizes between the big
    spot and Read along's corner (`DeckArtworkSpot` preference,
    `movingArtwork`); before, two copies cross-faded with the corners and
    shadow jumping.
  - **Smoother scrolling**: Up next (kept alive behind the other tabs)
    read the player's clock and refetched every episode twice a second,
    redrawing the whole page even while Shows / Find scrolled; now a
    10-second playhead snapshot (`DeckPlayheadWatch`, `plan.playhead`) and
    the top card follows the clock only while on screen
    (`deckPageShown`); fan list no longer reports every scroll frame;
    card shadows cast from the plain shape (`deckPlainCard`, fan card,
    show tiles); Find's chart and results lazy; `TimeFormat.ago` reuses
    its date formatters.
  - **1 Sleep timer: End of chapter** in the Options sheet's sleep list
    (episodes with chapters; uses `setStopAtChapterEnd`, fades and pauses).
  - **2 Up next suggestions**: when one or no episode is left after the
    one playing, up to three suggestions under the deck (and at the foot
    of the full list): started ones, then the last two weeks from Top
    shows by rank, then other shows; + adds (Undo), tap for the episode
    page (`DeckUpNextSuggestions.swift`, `store.deckSuggestions`). The
    top card gives up height (to 340 pt) so they fit.
  - **3 Skip ads per show**: Default / Always / Never in the show's
    settings sheet (Deck and older looks), synced as "showAdSkip"
    (`ShowAdSkip`, `PlayerModel.skipsAdsForCurrentShow`).
  - **4 Weekly recap** at the top of Stats ("Your week": listened,
    finished, saved since Monday, top show) (`weeklyRecap()`).
  - **5 Save for later**: bookmark key on the Deck episode page and in a
    show page episode's hold menu; list on the Shows tab under Carry on
    and in Settings → Your listening (`DeckSavedForLater.swift`); synced
    as "savedForLater" (episode IDs, one per line, newest first, 300 at
    most); played episodes drop off.
  - **6 Apple Watch**: no build needed: the watch's own Now Playing shows
    play / pause / skip and volume for Poddeck (Watch app → General →
    Wake Screen → Auto-launch audio apps). A real watch app later if
    wanted.
  - **7 Going live prep**: instant alerts only for the owner's phone
    (`RealtimeAlerts`: the phone that created the public "follows"
    record; others don't publish follows, don't subscribe and remove old
    alert subscriptions; "alertsOwner" re-checked daily; their status
    line says alerts come from the background check). Privacy and
    support pages `docs/privacy.html`, `docs/support.html` (linked from
    the site footer; App Store Connect URLs
    https://poddeck.uk/privacy.html and /support.html; App Privacy
    "Data Not Collected"). Support page still needs a real contact
    address before submitting.

- **Up next list rows reworked** (Paul, 15 Nov 2026, screenshot: "a
  little out of place and not well proportioned"): everything centred in
  a 96 pt card: 60 pt artwork, then show (caps), title (two lines' room)
  and one info line "17:08 · 1h 1m  DL TX"; the ≡ handle level with it
  (`DeckUpNextFan` row).

## Done in build 159 (15 Nov 2026, PR #77; Paul: "add it all and build")

- **Last row of the full Up next list under the tab pill** (Paul, 15 Nov
  2026, FNB, build 158 screenshot): the "Keep playing new episodes" row
  at the foot of the fanned list can't scroll clear: the pill and the
  page-colour fade behind it cut through its title and switch. Plan: give
  the fan list (and any Deck list ending in a row like this) bottom room
  of the pill's height + fade + 16 pt, so the last row always scrolls
  fully above the pill.

- **Ring / dial on the player?** (Paul, 15 Nov 2026: "ideas about somehow
  incorporating a ring or dial display into the now playing screen … not
  sure what I mean yet"). Ideas given in chat (progress ring round the
  artwork with chapter ticks, scrub by dragging round it, play key ring,
  sleep / chapter rings, ring that shrinks into Read along). Mock-ups of
  all seven on the Deck player: https://claude.ai/artifact/NAcNA5PK5DvzThGXqF2v2R
  (1 progress ring round the artwork with chapter ticks, 2 dial: round
  artwork, drag round the ring to scrub, finer towards the middle,
  3 chapter ring, 4 ring round the play key, 5 sleep timer ring, 6 ring
  follows into Read along, 7 the same ring on Carry on / mini player).
  Suggested 1 + 2 + 7. Paul (15 Nov 2026): "could be the next thing to
  help stand out … just unsure how transcripts fit in". Transcript ideas
  given: scrub by words (the dial's bubble shows the line said at that
  point), words inside the circle (tap the artwork, it turns over to the
  line being said, the ring keeps going), search / clip marks as dots on
  the ring, chapter segments named from the transcript, the line curved
  along the ring. Suggested scrub by words + words inside the circle +
  marks on the ring. Paul asked if it works on the Up next top card too:
  yes, as a display ring round the round artwork (the card's left / right
  swipes would fight a drag-round dial, so scrubbing there would need a
  touch and hold first, or stay in the player); its words key turns the
  circle over to the line being said. Then (Paul: mock the app with the
  dials, and a Safari-style app where each episode is a tab you close /
  mark played, Discover and Your shows as pinned tabs):
  https://claude.ai/artifact/26rUAiLq5wFzQRJzqUcEL7. 1 The dial: Up next
  top card with a ring round round artwork + words key, the player dial
  (tap to turn over to the words, drag round to scrub with the line at
  that point in the middle, clip / search dots on the ring), Shows with
  rings on Carry on / new / mini player. 2 Episodes as tabs: tab overview
  (Up next as tabs in queue order, × closes = played with Undo, tab
  groups Up next / New / Saved, pinned Find / Your shows / Discover), an
  open tab (player as a page, Safari-style bar at the bottom: swipe along
  it for the next tab, count opens the overview), a pinned Your shows
  tab. Note on the page: the two fit together (ring as each tab's
  progress, the dial player inside a tab). **Paul: "Dials and tabs!",
  build all of it into the next build** (15 Nov 2026). Built on the
  branch by three helpers, merged, not built yet: Paul:
  "do the same gestures like Safari too. Swipe up to get to tabs etc":
  swipe up on the bottom bar for the tab overview, swipe along the bar
  for the next / previous tab, swipe a tab card sideways to close it
  (played, Undo), pull an open tab down to go back to the overview.
  - **Rings across the app** (`App/DeckRings.swift` on top of the shared
    `DeckRing` / `DeckRingArtwork` in `App/DeckRing.swift`): Up next's top
    card (Standard / Calm) is a centred circle (round artwork in a 6 pt
    ring in the show's colour, live for the one playing); the words key
    flips it over to the words (dark circle in the show's colour; "No
    words yet" + Transcribe now / progress + Stop); download key bottom
    left, words key bottom right; tap the circle for the player. Big
    buttons / Read along: 56 pt ring artwork. Stacked cards, the full
    list, suggestions, Saved for later: round artwork, faint track, fill
    once started. Carry on: ring in the show's colour. New list rows and
    the catch-up card: coral "new" ring. Mini player: live ring in the
    show's colour (`DeckMiniRingArtwork`).
  - **The player dial** (`App/DeckPlayerDial.swift`): round artwork in a
    white ring with chapter cuts, amber ads, white clip dots and a knob;
    drag round to scrub (one turn = the whole episode; half / quarter
    speed towards the middle; seeks on release; Undo for 2 min+ jumps,
    shared `DeckScrubJump`; tick at chapters); while dragging the middle
    shows the time, the line said there and the speed; tap turns it over
    to the line being said now ("deckDialWords"), Transcribe key when
    there are no words. Read along opens from its button only; the
    picture shrinks into the corner with its ring. The straight scrub line
    is gone under the dial but stays in Read along. Swiping down on the
    dial scrubs, so close the player from the top row / title / round it.
    VoiceOver: one adjustable Position control. Not done: search hits on
    the ring.
  - **Episodes as tabs** (`App/DeckTabs.swift`, `DeckTabsGrid.swift`,
    `DeckTabsPager.swift`, `DeckTabsBar.swift`): Settings → Look → "Up
    next as" Tabs (default) / Card deck ("deckHome", this iPhone). Tabs
    home: header with "n · done by" and the gear; pinned Find (focuses
    the search box), Your shows, Discover (opens Find); groups Up next /
    New / Saved ("deckTabGroup"); two-across tab cards (show strip with
    ×, artwork, title, small coral ring + time; playing tab has an ink
    edge); × or swipe a card left closes it (Up next / New: played with
    Undo; Saved: off the list with Undo); hold for Play now, Play next,
    Remove from Up next, Episode notes, Save for later; drag to reorder
    in Up next (shares the long press with the menu: check). Tap a tab:
    full-screen pager (swipe sideways through tabs, big ring artwork,
    Play / Pause, Open player for the one playing, Play next / Notes /
    Played) with its own Safari bar; pull down to go back. Bottom bar in
    tabs mode replaces the pill and mini player: what's playing (ring,
    title, play / pause; tap for the player), count square on Shows /
    Find back to the overview; swipe up on it for the overview, swipe
    along it for the next / previous tab. Card deck mode is unchanged.
    The full Up next list's last row ("Keep playing") now scrolls clear
    of the pill (the FNB queued above).
  - Playable mock-up of the whole new look (tabs, Safari gestures, the
    dial): https://claude.ai/artifact/6BdEF6Us4AZoB7smk6zSe7. **Switching
    between pinned pages** (Paul, 15 Nov 2026: "I need a better way to
    switch between find, your shows and discover"): suggested Discover
    folded into Find (empty search = New to you + charts), a "Tabs · Your
    shows · Find" switcher of words at the top of each pinned page, and
    swiping along the bottom bar moves between those pages (swipe up still
    = tabs); then edge swipes instead of the bar. **Paul: "add it all and build"** (15 Nov 2026): built
    (`App/DeckSections.swift`, `.deckSections(current:)` on the tab grid,
    Your shows and Find's first pages): the row of words "Tabs · n · Your
    shows · Find" at the top of each (the pinned tab pills are gone; Find
    with an empty box is Discover), and a swipe that starts at the left /
    right screen edge moves to the section before / after (only on each
    section's first page, so iOS's own swipe back still works on pushed
    pages). Swiping along the bottom bar still moves between episodes;
    swiping up still shows the tabs. Reorder Up next: touch and hold a
    tab, then drag it onto another tab's place (shares the hold with the
    menu: check on the phone).


## Done in build 160 (16 Nov 2026, PR #78; Paul: "Option 1 and build")

- **Show page: playing episode readable** (Paul, 16 Nov 2026, build 159
  screenshot of 606: the played / paused episode was a black card, hard
  to read). Done: it's a white card like the others with a
  2 pt ink edge, ink title, the show's colour dot, and "Playing" /
  "Paused" in the show's colour on the meta line; its opened keys are the
  normal ones (`DeckShowEpisodeCard` / `DeckShowEpisodeText`).

- **Add an episode without following the show** (Paul, 16 Nov 2026: "in
  discover, if I click into a podcast, I want to be able to add an
  episode to my queue without following the show … try out a show
  without subscribing if they have a particular guest or topic"). Done (`App/TriedShows.swift`): every episode card on a show
  you don't follow (Deck show preview from Find / charts) has "+ Up
  next" and "Play next" ("In Up next" once there; Undo). The show is
  saved as a "tried" show (Nowhere, no downloads, no alerts, its feed
  not checked), listed in the synced setting "triedShows", and left out
  of Your shows, Find, Search, settings lists, CarPlay, the alerts job
  and OPML export (`followedOnly`, `store.followedPodcast`). It's tidied
  away at the next feed check once none of its episodes are in Up next,
  playing or part-played. Follow (preview, or the Follow pill on its
  show page in place of Following) turns it into a normal followed show
  (Bottom, downloads on). Older looks' preview page not changed.

- **Smoother scrolling and animations** (Paul, 16 Nov 2026: Your shows
  "very jerky … scrolling and animations need smoothing throughout").
  Done: the Shows tab worked out each show's new episodes
  by walking every episode of every show on every redraw; now one fetch of
  the week's unplayed episodes, kept between redraws (`DeckShowsCache`,
  remade when shows, ranking, the last feed check, Undo, the hour or a
  return to the page change); the sideways show row and All your shows
  grid only rebuild when that list changes (`.equatable()`), the grid's
  sort is kept (`DeckShowsSortMemo`), tiles drawn once (`drawingGroup`);
  the mini player and tabs bar only redraw their ring and time-left line
  with the clock (`DeckMiniTimeLeft`, `DeckTabsBarRing`); the tab pager's
  pull-down no longer refetches tabs each frame; the show page keeps its
  episode sort; `CachedImage` doesn't reset a picture already shown; the
  section edge swipe no longer lays strips over the screen edges that
  swallowed scrolls starting there (`DeckSections` edge swipe now runs
  alongside scrolling). Check on the phone: Shows tab scrolling, the tile
  names' sharpness, new counts updating after playing / marking played.
  Mock-up of everything in this build:
  https://claude.ai/artifact/TgbPAWS9vWQQvMvaCLTYC2.
- **"Play next" / "Add to end"** (Paul, 16 Nov 2026: "+ Up next" and
  "Play next" were "quite close … meaning wise"; picked option 1): the
  show preview's keys are Play next (ink, first) and Add to end; the
  Deck show page's far right swipe and opened-card key say Add to end
  (were Play last).

## Done in build 161 (16 Nov 2026, PR #79; Paul: "lets try corner shade and build")

- **Order numbers on Up next tabs** (Paul, 16 Nov 2026: "add a number to
  the up next tabs to make it clear the order"). In the Up next group
  each tab card shows its place on the artwork's top-left corner: "Now"
  on the one playing, then 1, 2, 3… for what comes after
  (`DeckTabsGrid.place`, `DeckTabCard.placeBadge`). New and Saved tabs
  have none. First an ink pill; Paul: "a bit too strong". Options on
  https://claude.ai/artifact/PsQEdGqw4K5GF6Aq7SfHXn (A pill, B plain
  number, C in the show line, D frosted dot, E outline numeral, F in the
  time row; then B1 glow / B2 corner shade / B3 both, on pale artwork).
  **Paul picked B2 corner shade**: a plain white 14 pt heavy number over
  a faint dark radial shade fading from the corner (42% black, 64 pt).
  For the queued tab work: the number stays in that corner on the
  full-colour cards, renumbers live during the hand-made drag, and an
  open tab's top line says "2nd in Up next" / "Playing now".

## Done in build 162 (16 Nov 2026, PR #80; Paul: "i wanted them built 2 builds ago!")

- **Tabs: hand-made drag to reorder** (Paul, 16 Nov 2026, build 159
  recording: the lifted tab dropped down on its own and it wasn't clear
  which tab it was replacing). In the Up next group, touch and hold a
  tab (0.35 s, a tick): it lifts right where it is, a little bigger with
  a shadow, and follows the finger; the other tabs slide out of the way
  into their new places as it moves (a tick at each), their corner
  numbers renumbering as they go; a dashed gap shows where it will land;
  let go and it settles into the gap and Up next takes the new order
  (same `moveQueue` as the other reorders). Hold and let go without
  moving gives the tab's menu (Play now, Play next, Remove from Up next,
  Episode notes, Save for later). A swipe that starts without the hold
  scrolls as usual; the page doesn't scroll while a tab is lifted. The
  tab playing ("Now") stays first and can't be moved. New and Saved tabs
  keep iOS's own hold menu. VoiceOver: Move earlier / Move later / More.
  `DeckTabsGrid` (`DeckTabHold` long press, `DeckTabLift`, the lifted
  copy drawn over the grid), `DeckTabsModel.reordering`. Not done: the
  page doesn't scroll by itself when a tab is dragged to the top or
  bottom edge, so a tab moves within what's on screen (drag, scroll,
  drag again for long moves). Check on the phone: scrolling that starts
  on a tab, the hold timing, the menu after a still hold.
- **Tabs in full colour** (Paul, 16 Nov 2026): each tab card is its
  artwork filling the card, fading at the foot into the show's colour
  (`DeckRings.showColour`), where the show (small capitals), the title
  (two lines' room) and the time left / date sit in white beside the
  small progress ring (white on the colour). × top right on a soft dark
  circle; the order number in the top left corner as before (corner
  shade); the tab playing has a dark 3 pt edge with a thin white line
  inside so it shows on any colour. Same two-across grid; every card is
  now the same height (1.25 × its width) (`DeckTabCard`). Check on the
  phone: white text on pale artwork colours.
- **One tab = player + episode page + show settings** (Paul, 16 Nov 2026,
  FNB: "when you tap through on a card can it open the episode in a
  player mode with all the standard player interface and the show
  settings folded in … so we don't have a separate player and episode
  screen, they're all the same tab"; mock-up
  https://claude.ai/artifact/BRGBBkaHhpuDnarzHTxBPS). In tabs mode,
  tapping a tab opens one scrolling page for that episode
  (`DeckTabEpisodePage`, shown by `DeckTabsPager` in place of the old
  ring page):
  - Top: the Deck player on the show's colour, built from the player's
    own pieces: ⌄ back to the tabs, "PLAYING NOW" / "PLAYING ON …" /
    "2ND IN UP NEXT" / "TAB 3 OF 7" and a ⋯ menu (Play next, Remove from
    Up next, Open show); the dial; show (opens the show) and title; the
    chapter row; times; skip · play · skip; volume on tall screens;
    Options · Read along · Chapters · AirPlay. A tab that isn't playing
    has the same layout at rest: its saved place on the ring, the saved
    time / time left, dim skips and a big white Play (the artwork plays
    too); pressing it plays that episode and the page goes live. Read
    along works on any tab (the words fill the top, small ringed artwork
    to go back).
  - Then, on the app's own page colour rising like a sheet, "This
    episode": Playing now / "2nd in Up next" (Play next) / Not in Up next
    (Add), Download (progress, Stop, Remove with a check), words
    (Transcribe now, progress, Stop; "Words ready · Read along" scrolls
    back up with the words showing), Played (with Undo; in Up next and
    New the tab closes) and Save for later; then the episode notes.
  - Then "This show": the show with Open show, New episodes go Top /
    Bottom / Nowhere (`DeckShowRulePicker`, now shared), and the show's
    own settings (downloads, alerts, keep downloads, speed, skip intro /
    outro, skip ads, older episodes): `DeckShowSettingsSections`, now
    shared with `DeckShowSettingsSheet`, which looks the same as before. A
    show only being tried shows Follow this show instead.
  - Scrolled down past the player, a slim bar pinned at the top keeps the
    ringed artwork, title, time and play / pause; tap it to go back up
    (`DeckTabSlimBar`).
  - Swipe sideways for the next / previous tab as before; pull down past
    the top of the page (80 pt) and let go for the overview (the page
    watches its own scroll; the old pull-anywhere gesture is gone, so
    scrolling back up and dragging round the dial never close it).
    Safari's bar at the bottom is unchanged.
  - No separate player in tabs mode: tapping what's playing on the bottom
    bar, quick actions and anything else that opened the full-screen
    player now open the playing episode's tab (`DeckRoot.openPlayingTab`;
    in the New group it switches the overview to Up next first).
    RootView's full-screen player stays shut in tabs mode. Card deck mode
    keeps `DeckPlayerView` and `DeckEpisodePage` exactly as before.
  - To check on the phone: pull down to close from the top of the page
    (and that it doesn't fire when scrolling back up), scrolling the page
    when the finger starts on the dial (the dial takes the drag, so start
    beside it), the sideways swipe between tabs while scrolled down, the
    slim bar appearing, Play on a tab that isn't playing, Open show (the
    tab closes, then Shows opens the show), smaller iPhones (the dial
    shrinks to fit).

## Done in build 163 (16 Nov 2026, PR #81; Paul: "great. build.")

- **Tabs: hold and drag fixed, swipes back** (Paul, 16 Nov 2026, build
  162: "Hold and drag isn't working at all … Swipe left marks as played
  with a visual confirmation. Right gives us next or last (but keeps it
  first in a show group if it's the oldest)"; mock-up
  https://claude.ai/artifact/SYxmjsr1PGL9L8owLRUBCw).
  - Why the drag did nothing: each tab card had three gestures fighting
    for the same finger: the card was a button (tap to open), it had a
    sideways pan (swipe to close), and the hold sat on the cell around
    both. Because the hold was outside the button, SwiftUI made it wait
    until the button's tap had failed, and a finger held still never
    makes a tap fail, so the hold could never start (letting go just
    opened the tab). The hold also made every pan, the page's scrolling
    included, wait for it.
  - Now one touch handler per card decides once what the touch is
    (`DeckTabTouches` / `DeckTabTouchRecognizer` in
    `App/DeckTabTouches.swift`): let go within 0.35 s without moving = a
    tap (opens the tab); still for 0.35 s = a hold; moved 8 pt first,
    clearly sideways = a swipe; moved any other way = not ours, so the
    page scrolls at once with nothing waiting. A touch that stops the page
    scrolling doesn't open a tab, swipes that start at the screen's very
    edge are left for the section swipe, and × sits outside the handler so
    a tap on it is only ever ×. iOS's own hold menu is gone from the
    cards: a still hold on any tab gives the tab's menu (now with Play
    next and Add to end).
  - Hold and drag as built in 162 (lifts in place, the others slide,
    numbers follow, dashed gap, the playing tab can't move), plus the page
    scrolls by itself when the finger is within 90 pt of the top or bottom
    (faster nearer the edge), with the slots worked out allowing for it.
  - Swipe left = Played (`DeckTabCell`, `DeckTabSwipeBlock` in
    `App/DeckTabsGrid.swift`): the card follows the finger over a red
    block with ✓ "Played"; past 38% of the card (or a quick flick) the ✓
    goes white with a tap; let go and the card springs back, a white
    "✓ PLAYED" pill shows on a dark wash, then it folds away and is marked
    played with Undo. Saved tabs say Remove (off the Saved list).
  - Swipe right: grey to 28% of the card, then green "Play next" (to
    62%), then ink "Add to end", a tap as each one is reached; let go and
    the card springs back, Up next changes and the tab glides to its new
    place with an ink ring pulse; Undo. Both keep each show in order
    (`DeckTabActions.playNextInOrder` / `addToEnd`, through
    `QueueEngine.playNext` / `playLast`; Add to end also moves a tab
    already in Up next). The Undo bar says where it went ("Playing next ·
    3rd") and, when show order moved it, why on a second line ("After
    “Lanterns on the river…” to keep Paper Lanterns in order"; episodes
    have no numbers, so a short title) (`UndoAction.note`, shown by the
    Deck Undo bar). The tab playing only swipes left; New tabs swipe both
    ways; Saved tabs only left.
  - Check on the phone: hold then drag (and the hold timing), scrolling
    that starts on a card, auto-scroll near the top / bottom (it uses the
    finger's height, not the card's middle), the swipe distances on a
    small card, the Played pill timing, the ring pulse after the tab
    moves, a tap on × and a tap just after scrolling, VoiceOver actions.

## Done in build 164 (16 Nov 2026, PR #82; Paul: "add the pill and build")

Paul's notes after build 163, built by two helpers plus option A:
- **Section edge swipe follows the finger** (Paul: "doesn't animate as
  you move … the scroll up and down activates and twitches the display"):
  a swipe from within 20 pt of the left / right edge, clearly sideways,
  now drags the section on screen with the finger while the real
  neighbouring section slides in (dimmed 12% at first); let go past 35%
  of the width or flick to move on (0.32 s spring), otherwise it springs
  back; no section that way = rubber band; a tap at the commit point.
  Once it starts the page's own scrolling is cancelled, so it can't
  twitch. `DeckEdgeSwipeRecognizer` / `DeckEdgeSwipe`, state in
  `DeckSectionSwipe` (`\.deckSectionSwipe`), pages moved in `DeckRoot`.
- **Tabs · Your shows · Find at the bottom: option A** (Paul: "lets try
  A" from https://claude.ai/artifact/WmSfBvAqQ4Fk4QWXSspeLH): the words
  row left the top of each page and is the second row of the bottom bar,
  under what's playing, the page you're on in ink with a short line
  (`DeckTabsBar`, `DeckBarSectionWords`; bar 101 pt). Tap a word (Tabs
  also closes an open tab), swipe along the bar for the page before /
  after, swipe up for the tab overview. Swiping along the bar no longer
  moves between episodes; the count square is gone (the count is in
  "Tabs · 6").
- **Open tab page**: controls start below the Dynamic Island (the colour
  still runs up behind it; `DeckTabsPager` passes the safe area to
  `DeckTabEpisodePage`); the Safari bar inside the page is gone (swipe
  sideways on the page for the next tab; `DeckTabsPagerBar` deleted);
  pull down to close is a UIKit pan (`DeckPullDown`, `App/DeckPullToClose.swift`):
  when the page is at the top, a downward drag anywhere but the live dial,
  read-along words / scrub line and volume moves the whole page with the
  finger and closes past 64 pt or a flick (300 pt/s, or predicted
  120 pt), else springs back; the card-deck player's `closeSwipe` uses the
  same distances. The "This show" section is gone from the page (Paul:
  keep it in the show's settings); under Save for later one row "Go to
  show · name ›" (`DeckTabGoToShowRow`). The ⋯ is a small sheet in the
  app's colours (`DeckTabMoreSheet`: warm page, white card, ink) instead
  of iOS's glass menu, which took a purple tint from the show colour
  (Paul: "kind of purple tint"); the Options sheet's sleep list is ink.
- **Gap between title and times** (Paul: "no man's land … looks like
  something failed to render"): spare height goes above the dial, the
  title sits close over the chapter row and times; times in Outfit
  semibold 18 with steady digits (`DeckDialTimes`, 26 pt row), both
  players.
- **No chapters** (Paul: "and when there are no chapters present?",
  then "add the pill and build", from
  https://claude.ai/artifact/2BB2UmYB1yN474wjoad1HG): the chapter row
  shows a faint outlined pill "No chapters · Make them ›" instead of an
  empty band (`DeckChapterRow`); it opens the chapters sheet, which with
  no chapters has a card explaining they're made on the iPhone from the
  words and a Make chapters key (Transcribe now, downloading first if
  needed; shows "Making the words first · 62%"; the chapters appear when
  done) (`DeckMakeChaptersCard` in `DeckPlayerChapters.swift`).
- **Undo bar on dark art**: a touch lighter ink (#2A2826), a fine white
  22% edge and a stronger shadow (`UndoBar.deckBarBackground`).
- **Tab card × and number**: × is a 26 pt circle in 58% black with a
  white 35% edge and soft shadow; the corner shade behind "Now" / 1 / 2…
  is darker and larger, number 15 pt with a glow (`DeckTabCard`).
- Check on the phone: edge swipe on a page never opened yet (it's made
  as the swipe starts), vertical scrolls starting near an edge, the
  Undo edge on the light page, pull down on the tab page vs scrubbing the
  dial (if the dial closes the page, the no-pull areas are off), no
  doubled gap under the island, long times ("1:23:45") on small iPhones,
  the bottom bar's words on a small iPhone.

## Done in build 165 (16 Nov 2026, PR #83; Paul: "include all that and build")

Paul's notes after build 164:
- **Pull down to close with Read along open** (Paul: "I can't pull down to
  close when the transcript is open"): the pull (`DeckPullDown`) now also
  starts on the read-along words when they're scrolled to their top (it
  checks the scroll view under the finger, `scrollUnder`), and the top
  row and the small artwork / title header always take it; only the dial
  (listening) or the scrub line (reading) are kept out (`pullKeepOut`).
  The card-deck player's words do the same (`pulledOnWords`). The words
  follow playback, so mid-episode pull from the top row / header.
- **Edge swipe between sections removed** (Paul: "let's get rid of edge
  scrolling; the menu being at the bottom gives us what we need"):
  `App/DeckSections.swift` deleted; pages just show / hide; card swipes
  work from the screen edge again.
- **"n new" on show tiles** (Paul: "the 1 new being black … do we make
  it white with a shaded corner like in tabs"): first `DeckCornerShadeLabel`;
  then (Paul, 16 Nov 2026: "do we make it red like the other") the same
  coral pill as the tabs' NEW, "2 NEW", in the top-right corner of
  `DeckShowTile`.
- **Tab groups: Up next · New · Started, as chips above the bar**
  (replaced the same day: see "New and the group pill gone" below) (Paul,
  16 Nov 2026, option A of the mock-up: "let's get rid of saved and have up
  next, new and started as chips above the bar, and shows alone on the
  your shows tab. Started should be anything started"). Tabs mode only;
  card deck mode is unchanged.
  - The chips that sat at the top of the Tabs page are gone. On the Tabs
    page only, a small white pill floats just above the bottom bar,
    centred: the chosen group in ink with its count ("Up next · 6"), the
    others as muted words; tap one, or swipe along the pill for the group
    before / after, instantly (`DeckTabGroupPill` in DeckTabsBar.swift).
    It hides while a tab is open and on Your shows / Find. The Tabs page
    has that much more room under its last row (`DeckTabsBar.pillRoom`),
    and its Undo bar sits above the pill (`RootView.deckToastLift`).
  - **Started** (`DeckTabGroup.started`, `DeckTabSource.startedQuery` /
    `started`): every episode started and not finished (more than 30 s
    in, not played), Up next ones included, the one playing first, then
    most recently played. Tabs show their progress ring as usual; swipe
    left / × = Played, swipe right = Play next / Add to end, the hold menu
    as New's; no order numbers (only Up next has them). Empty: "Nothing
    started".
  - **Saved for later is gone** from the Deck look: the Saved group, the
    Save for later row on a tab's page, the hold menu items, the bookmark
    key on the card-deck episode page, the show page's hold menu item,
    Settings → Your listening → Saved for later and the Shows tab's Saved
    list. `App/DeckSavedForLater.swift` (`SaveForLater` and its views) is
    deleted and "savedForLater" no longer syncs (an old saved choice of
    the Saved group opens Up next). Played no longer touches it.
- **Your shows = the shows alone** (tabs mode; Paul's pick "Shows
  alone"): the page is just "Your shows", "n followed", the ⇅ sort key
  and +, then every show as the two-across tiles in the chosen order
  (`DeckShowsAloneHeader`, `DeckAllShowsRow(labelled: false)`, the sort
  key is now its own `DeckShowsSortMenu`). Carry on, the sideways row of
  new-episode show cards, its catch-up and the New sheet aren't on it any
  more (New and Started are tab groups now). Card deck mode still shows
  them, so that code stays.
- Check on the phone: the pill's place over the bar on a small iPhone,
  the last row of tabs scrolling clear of pill and bar, Undo above the
  pill, swiping along the pill vs. the bar's own swipes, Started's order
  while something plays (the one playing stays first), an episode only
  just started (30 s) appearing in Started.
- **Tab swipe-away smooth** (Paul's recording of build 164: "the
  disappearing card animation when swiped away is very jerky"; frame by
  frame the card snapped back, sat with a ✓ PLAYED pill, then just
  vanished, and Undo popped it back): an armed left swipe now carries the
  card on off its slot, fading, while the ✓ on the red block grows; ×
  shrinks and fades it; then the tabs close up in one animation, the
  corner numbers rolling (`DeckTabCell.flyOff` / `closeTapped` /
  `settle`, `DeckTabsGrid` keeps its own `mirror` of the tabs and a
  `gone` set so the gap closes at once; `DeckCornerShadeLabel` numeric
  roll). Undo fades / grows the tab back; `undoable`'s restore now runs
  in one animation everywhere. Not far enough: a real spring back.
- No chapters pill: Paul was likely still on 163; on 164 it shows on the
  playing tab (a tab not playing has no chapter row).

- **New and the group pill gone: Up next only, new ones flagged**
  (Paul, 16 Nov 2026, after the New group lost its "already looked at"
  list: "everything new adds to up next in the relevant place based on
  its rules … new episodes have an indicator … we drop the new pill. so
  the up next tab is simple"). Tabs mode only. The Up next · New · Started
  pill above the bar is gone (`DeckTabsBar.pillRoom` 0; `DeckTabGroupPill`
  kept, unused) and the Tabs page is always Up next (`DeckTabGroup` is Up
  next / Started; the model always starts on Up next). New episodes reach
  Up next by their show's rule as they always did (Top / Bottom; Nowhere
  shows don't add, so theirs stay on the show page). An Up next tab whose
  episode came out in the last 48 hours and isn't started or playing has a
  small coral NEW pill before the show's name (`DeckTabSource.isFresh`,
  `DeckTabCard.newFlag`). Started went with the pill: started episodes in
  Up next show their progress ring; ones started but not in Up next
  (picked from Find, a show on Nowhere) sit under the tabs as Carry on
  cards, up to three (Paul: "could have a carry on card below the up
  next"; `DeckCarryOnSection(outsideUpNext: true)`: ring artwork, title,
  show · time left, ▶; tap for the episode page). Mock-up:
  https://claude.ai/artifact/UiDf53LQZssTvUkaWjMjs9. Card deck mode unchanged.

## Done in build 166 (16 Nov 2026, PR #84; Paul: "Build")

- **Ad detection switched off** (Paul, 16 Nov 2026: "remove ad detection.
  It doesn't work as I want so let's just drop it for now"). One switch,
  `AdFeature.enabled = false` (Models.swift): nothing looks for ads any
  more (on-device passes, the show's own transcript, Find ads while
  listening; `TranscriptService.prepare` no longer re-transcribes just for
  ads), every episode reads as having no ad breaks (`adBreaks` returns
  none, so no Skip ad, amber ad marks on the dial / line, ad bands in the
  transcript or Sponsor break chapters), and the ad settings are hidden
  (Settings' Find ads / Skip ads automatically, the show's Skip ads, the
  older looks' Ads section, Stats' ADS SKIPPED). The transcript sync
  check stays. Breaks found before are kept in the saved data, unseen;
  set the switch to true to bring it all back. The website still has its
  small "Ad breaks · optional, off by default" card: take it out next time
  the site is touched.
- **Words in the dial: tap the artwork** (Paul, 16 Nov 2026: asked for a
  switch to show the words in the dial; then, on learning tapping the
  artwork already does it, "I want read along to just function as
  before"): no extra key and no change to Read along (it still switches
  between the player and the full words). Tapping the dial's artwork
  turns it over to the line being said and back, remembered as
  "deckDialWords" (as before).
- **Chapters button gone from the player's bottom row** (Paul, 16 Nov
  2026: "drop the chapters button and space out the other 3"): Options ·
  Read along · AirPlay, evenly spread; chapters open from the chapter row
  under the title (the pill, or "No chapters · Make them ›"). Both players.
- **"This is playing now" in Read along** (Paul, 16 Nov 2026, transcript
  sync issues again, on an episode listened to across several builds; he
  will test more): hold any line in Deck's Read along (while that episode
  plays) for Share a clip / Copy / This is playing now; the last lines
  the words up so the held line is at the play point from there on (a
  sync anchor, like the older looks' transcript screen), with a tap, and
  following resumes (`DeckReadAlong.syncHere`).

- **Read along: the times shrink smoothly** (Paul, 16 Nov 2026: "when
  tapping read along, can we make the animation on the numbers getting
  smaller and moving smoother like the chapter pill moving"). Before, the
  big times row under the dial and the small one under Read along's
  straight line were two different rows swapped with a fade, so the
  numbers popped. Now there's one row (`DeckDialTimes(compact:)`): in Read
  along the line fades in above it and the numbers shrink in place (a
  scale from 18 to 12 pt anchored at each edge, the row's height 26 to
  16), on the same 0.4 s move as the chapter pill. Dragging the line still
  shows the time and "Half speed" etc. in the row (`DeckPlayerScrub(shared:)`
  writes into `DeckDialScrub.time / hint`). Both players.

- **Read along lights the words as they're said** (Paul, 16 Nov 2026:
  "the transcript follows the sentences paragraphs but doesn't highlight
  words as spoken"; the Haar look had it, the Deck look's `DeckReadAlong`
  never did). On the line now: words said in full white, the word now
  white on a soft white mark, words to come faint (`lineText`,
  `litText`, `DeckReadAlongWords`). Transcripts time lines, not words, so
  the word is worked out across the line by its letters, and between the
  player's twice-a-second reports it runs on the clock 10× a second
  (`TimelineView`), only on the line now while this episode plays. It can
  only be as right as the line timing, so it shares the sync issue below.

- **Pull down to close keeps you where you were** (Paul, 16 Nov 2026,
  FNB, recording of build 165: pulling the player down on Your shows or
  Find "snaps me back to tabs"): the tab page goes back to the page it was
  opened from (`DeckTabsModel.returnTab`, set by `DeckRoot` when the pager
  opens); opened from the Tabs page it still goes to the overview.
- **Tap "Your shows" / "Find" again to go back** (Paul, 16 Nov 2026,
  FNB): tapping the bottom bar's word for the page already showing goes
  back to its first screen (show pages and previews closed), like tapping
  an iPhone tab twice (`.deckPageToStart`). Card deck's pill too.

## Done in build 167 (17 Nov 2026, PR #85; Paul: "Build")

- **Remembers what was playing** (Paul, 17 Nov 2026: "If the app exits
  or closes, it forgets what was last playing … after a fresh wipe or if
  you go into the app, I'd want it to remember"). Opening the app loads
  the most recently played unfinished episode, paused at its saved place
  (`PlayerModel.restoreLastPlayed`, from each episode's `lastPlayedAt`,
  which syncs through iCloud). After a reinstall it comes back once
  iCloud has filled in the library: every iCloud tidy (`.libraryTidied`)
  tries again, and a newer one from a later sync swaps in, until Paul
  plays or picks anything. The place is also saved the moment the app
  goes to the background (`saveProgressNow`; it was every 15 s), so a
  closed app picks up exactly there. Finished episodes aren't brought
  back.

- **Read along polish** (Paul, 17 Nov 2026, build 166 recording;
  mock-ups https://claude.ai/artifact/Lov1Pwxoi3e2ryuoCCtMxo, he picked
  1 A, 2 A, 3 B):
  - The word being said is a light tint of the show's colour, with no
    block behind it (`DeckReadAlong.wordTint`: the show colour mixed 55%
    toward white).
  - Moving to the next line: every line is the same size (Outfit 19
    semibold); only the light changes (line now full white, others 40%)
    in a 0.5 s ease, with one smooth 0.5 s scroll. The line now used to
    grow to 24 pt, so lines below jumped and overlapped mid-scroll.
  - The tab page's "This episode" card starts fully off screen (it
    peeked up under Options · Read along · AirPlay); a small arrow at the
    foot of the player bobs gently until the page has been scrolled down
    once ("deckMoreHintSeen", this iPhone), then sits still; tap it to
    scroll down to the card (`DeckTabMoreHint`).
  - Read along's hold menu: its icons were white on iOS's light menu
    (they took the player's white text); now dark (`menuItems`,
    `.foregroundStyle(.primary)`). Copy gives a success tap. Share a clip
    and "This is playing now" work (Paul, 17 Nov 2026: the resync "seems
    to be working").

## Done in build 168 (17 Nov 2026, PR #86; Paul: "You can build one more")

- **One alert per new episode** (Paul, 17 Nov 2026: two pushes for #593
  of Elis James and John Robins, one from the instant alerts job via
  iCloud as it came out, one from the app's own check when he opened the
  app an hour later). On the phone with instant alerts
  (`RealtimeAlerts.instantAlertsOn`: owner + subscribed), the app's own
  feed check sends no alert of its own for bell shows; if the iCloud
  alert ("Show · Episode") is still in Notification Centre it's swapped
  for the fuller one ("Added to the top of Up Next") quietly (passive, no
  sound) (`NewEpisodeAlerts.post`). Other phones keep the app's alerts.
  If the iCloud alert was already cleared, the app can't tell it was
  sent, so nothing more shows.
- **Search hits on the dial** (Paul, 17 Nov 2026, yes; the one part of the
  dial design not built in 159): tapping a quote under Find's "Said in
  your episodes" remembers the phrase (`DeckDialSearch`); that episode's
  dial shows a small yellow dot just inside the ring wherever a line says
  it (every word, any case), and a pill in the dial's corner names it
  with the count ("“panini” · 6 ✕"); tap the pill to clear.
- **Simulator screenshots** (offered 15 Nov 2026): a GitHub
  Mac job that runs the app in a simulated iPhone with made-up shows,
  does the main gestures and saves screenshots for checking before Paul
  installs. Free while the repo is public; from 1 Dec (private) Mac time
  counts 10× against the free 2,000 minutes (~15 runs a month, stops at
  the limit, no charge). **Paul: "Let's see how this one goes first"**
  (build 159). **Paul: yes** (17 Nov 2026), built on a branch, not run
  yet: `.github/workflows/screenshots.yml` (by hand, or the PR label
  "screenshots"; never automatic) launches the app with `-PoddeckDemo`
  and `-PoddeckScreen <tabs|player|readalong|shows|showpage|find|settings|carddeck>`
  in light and dark and uploads the PNGs, the app log and any crash
  reports as the "screenshots" artifact. Demo mode (`App/DemoData.swift`):
  in-memory library, no iCloud / settings sync / push registration, no
  feed checks (`refreshAll` returns), six invented shows with drawn
  artwork, Up next, a part-played episode with auto chapters and a short
  transcript loaded paused. Hooks only in PodcastsApp, LibraryStore.refreshAll,
  AppDelegate (push registration), DeckRoot, DeckTabs (Settings) and
  DeckTabEpisodePage (Read along). How to run: notes/SETUP.md.
- **Old looks cleared out** (Paul, 17 Nov 2026: "Clear out the old
  looks"): Deck is the only look. `ColourScheme` is `deck` / `deckNight`;
  Settings → Look → Colours offers Auto / Deck / Deck night (any old
  saved value, "haar", "sand"…, counts as Auto and is rewritten to
  "auto"). `RootView` always shows `DeckRoot`. Deleted: Haar*.swift,
  NowPlayingView, MiniPlayer, UpNextView, UpNextExtras, LibraryView,
  DiscoverView, SearchView, Poster, ShowView, ShowSettingsView,
  PlayerTranscript, AddShowView, ChaptersView, DeckParts; the DM Mono,
  Fraunces Soft and Instrument Serif fonts. Pieces Deck still uses moved
  to their own files: PlayerOptionsSheet, PlayerSystemControls
  (`SystemVolumeSlider`, `RoutePicker`), SavedClipsView (was
  `HaarSavedClipsView`), TranscriptIndex, ChartHistory,
  TranscribeExplainer, UpNextTimes, UpNextPlace (was
  `EpisodeStatusRows.ordinal`), NewEpisodes (was `LibraryView.newFor` /
  queries), EpisodeMenuItems, ShowSettingChoices (was
  `ShowSettingsView.speedChoices` / `skipOptions`), RowParts (`posterCard`,
  `PosterRowText`, `Stamp`, `showTitle`…); `.haarPage()` is
  `.pageBackground()`. `Theme.isDeck` / `isHaar` / `rounded` are gone.
  Both Deck home modes (Tabs, Card deck) stay. The look history at the
  top of this file is history only.
- **Going live: notification options** (Paul asked 17 Nov 2026, for both
  real-time push and the app checking). Told him: 1 the app checks by
  itself (background refresh every 1 / 3 / 6 h, iOS picks the moment,
  plus on open; its own local alert): no outside provider, free. 2
  instant alerts for everyone needs something always on to check feeds
  and ask Apple to push (Apple's push via iCloud is free): a the free
  GitHub job made multi-user (sealed follows record per phone, per-user
  alert records; loose timing; tens to a couple of hundred users; grey
  area using free Actions as a service; minutes count once private), b
  the same job on a Cloudflare cron (more reliable; free plan may do for
  a few users, else $5 / month), c own server / paid push service (not
  worth it). Suggested: launch on 1 for everyone, Paul keeps instant
  alerts; move to 2b if people ask. **Paul agreed** (17 Nov 2026): that's
  the plan for going live (already how build 168 works: instant alerts
  only on the owner's phone).

## Done in build 169 (18 Nov 2026, PR #87; Paul: "build")

- **Tabs reshuffled just after opening** (Paul, 18 Nov 2026, recording:
  opened from closed, Up next's tabs showed in queue order with "Nothing
  playing", then a moment later the part-played episode jumped to the
  front as "Now" and the others slid along). Cause: build 167's "remember
  what was playing" loaded the last episode only once the app reported
  itself open, after the first screen was drawn, and the tab grid animated
  the change like a reorder. Now it's loaded before the first screen
  (`PodcastsApp.init` calls `restoreLastPlayed`), and if it still arrives
  later (iCloud filling in after a reinstall) the grid puts it first in
  one step with no slide (`PlayerModel.restoredEpisodeID`,
  `DeckTabsGrid.follow`). Up next's order itself never changed.

## Done in build 170 (19 Nov 2026, PR #88; Paul: "Build")

- **No artwork on the lock screen / Dynamic Island** (Paul, 19 Nov 2026,
  screenshots: Tailenders playing, blank grey square where the picture
  should be). The player fetched the episode's full feed picture (often
  3000 × 3000) from the internet afresh for Now Playing, apart from the
  app's artwork cache, and handed iOS that huge image at every size;
  offline or slow, nothing came. Now it uses the app's own cached copy
  (`ArtworkImageCache`, on the phone, at most 600 points) and draws it at
  the size iOS asks for (`PlayerModel.loadArtwork` / `makeArtwork`).
  Check on the phone: lock screen, Dynamic Island, Control Centre, CarPlay.
- **Paul's build 169 screenshots** (19 Nov 2026; tabs, dial with search
  dots, Read along, Options, the tab page, Deck night, Settings):
  - Tapping a quote in Find's "Said in your episodes" jumped to it and
    lost the place he was at: now "Jumped to 6:59 · Undo" puts you back
    where you were (same episode: back to the time; another episode: back
    to that one, playing if it was) (`DeckSaidRow.play`).
  - Search dots only appear after tapping a quote: as designed (the dots
    mark the phrase you opened that episode from). Offered: show them on
    the episode playing as soon as you search. **Paul: leave as is**
    (19 Nov 2026).
  - **Find in Read along** (Paul, 19 Nov 2026: "we need a search on the
    transcript page"): a round magnifier at the top right of the words
    opens a box ("Find in the words"); lines with every word typed (any
    case or accents) have the words marked in yellow, the one shown
    brighter, "2 of 6" with up / down keys (Return goes to the next);
    it starts at the first match from where it's playing, and following
    stops while a match is shown; Done closes it and following carries
    on (`DeckReadAlong` search, both players).
  - Pulling the player down got jerky once the dial had search dots
    (recording): every frame of the pull searched every transcript line
    again; now worked out once per phrase and transcript
    (`DeckDialSearch.hits`).
  - Options sheet Done: a white pill, right edge in line with the cards,
    level with the title (`PlayerOptionsSheet.header`).
  - Deck night switches were white on white (light ink tint, white knob):
    switches that are on are coral #EC6550 in Deck night, ink in Deck
    (`Theme.switchOn`; Settings, show settings, the tab page, Keep
    playing, Options with nothing playing). Done keys stay ink.

## Done in build 171 (21 Nov 2026, PR #89; Paul: "Go")

- **Old Undo coming back** (Paul, 20 Nov 2026: swiped an episode away as
  played, hours later opened the player and its Undo was still there).
  The 6-second timer lived in the Undo bar itself, so when the bar left
  the screen (closing the app, switching page) the timer stopped and the
  Undo was never cleared; the next screen with an Undo bar showed it
  again. Now the store clears it 6 s after it's offered whatever is on
  screen (`LibraryStore.undoAction` / `UndoAction.made`), leaving the app
  clears it, and coming back drops any that's past its 6 s.
- **App icon badge a step behind** (Paul, 20 Nov 2026: finished an
  episode, the next started, left the app: the icon still said 2 until he
  opened it again). The number was only worked out on opening / leaving
  the app and after a feed check, so Up Next changing in the background
  (an episode finishing on the lock screen, in the car) left it stale.
  Now it's worked out again a second after Up Next or what's playing
  changes (with the widgets' update, `WidgetSync.schedule`).

## Done in build 172 (21 Nov 2026, PR #90; Paul: "Go with U1 and the island, then build")

- **Tab stuck as a red "Played" block** (Paul, 21 Nov 2026, screenshot:
  marked an episode played with a swipe, added it back to Up next, and
  its slot showed the red Played block with the ✓ and no card). The card
  kept its "flown away" state when the same tab came back. Now a closed
  tab that's still there 1.5 s later (Undo, added back, or a close that
  didn't take) puts its card back in its slot, and a card shown again
  starts fresh (`DeckTabCell.comeBack`).
- **Up next as U1, the bar as one slim island** (Paul, 21 Nov 2026: "Go
  with U1 and the island, then build", from
  https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3). Tabs mode only.
  - The first tab (the one playing, else the top of Up next) is one big
    hero card (`App/DeckTabsHero.swift`): artwork fading into the show's
    colour, PLAYING NOW / PAUSED / UP FIRST, ✓ Played (Undo), show,
    title, a progress line with the time and time left, a big white
    play / pause; tap the card for its tab page. Under it "THEN" and the
    rest of Up next three across (`DeckTabsGrid.columnCount` 3, smaller
    card text; numbers start at 1 after the one playing, or 2 when
    nothing plays). Hold-and-drag, swipes and × work as before in the
    grid; the hero itself isn't dragged.
  - The bottom bar is one dark island 66 pt tall (`DeckTabsBar`): ring
    artwork with play / pause on it (with nothing on it starts the top
    of Up next), title and time left (tap for what's playing), then
    Tabs (coral count), Your shows and Find as white icons, the page
    showing lit with a soft circle. Swipes along / up the bar as before.
    Card deck mode unchanged.
  - Check on the phone: the hero on a small iPhone, three-across cards'
    text, dragging in the three-across grid, the island's keys' reach.

## Done in build 173 (21 Nov 2026, PR #91; Paul: "Merge")

- **Hero card works like the small tabs** (Paul, 21 Nov 2026, build 172
  screenshot: "have the same actions as the smaller ones … remove that
  played button. It's confusing"): the big first card uses the same
  touch handler as the tabs (`DeckTabCell(hero: true)`, wrapped by
  `DeckTabsHeroCell` in DeckTabsGrid.swift): tap opens its tab page,
  swipe left Played (red block, flies off, Undo), swipe right Play next /
  Add to end (not on the one playing), hold for the menu (Play now /
  Pause, Play next, Add to end, Remove from Up next, Episode notes). The
  ✓ Played pill is gone; the white play key stays, laid over the card
  outside the touch handler (`DeckTabsHeroPlay`). It isn't dragged into
  the grid.
- **Dashed "Find something" tile** (Paul: "I thought we were adding a
  dashed find something button", from the U1 prototype): always the last
  slot under THEN, so with only one episode it shows on its own; tap goes
  to Find (`DeckTabsFindTile`, `\.deckOpenFind`).

## Done in build 174 (22 Nov 2026, PR #92; Paul: "Yes")

- **Player: ring to look at, line under your thumb, colour sweep**
  (Paul, 22 Nov 2026, option 2: dragging round the dial was hard
  one-handed). Both players (the tab page and the card-deck player):
  - The dial no longer takes drags; it shows progress, chapters and
    search dots, and tapping it still turns it over to the words. Pull
    down to close can now start on it.
  - The straight progress line (`DeckPlayerScrub`) is always shown, just
    above the times and skip / play / skip, with the old line's rules
    (moves by how far the finger travels, lower for finer, bubble, Undo
    for 2 min+). While it's dragged the dial's middle shows the time,
    what's said there and how fine.
  - The artwork starts black and white and its colour sweeps in round
    the circle as you listen, in step with the ring (`DeckDialSweep`).
  - Check on the phone: dial size on a small iPhone (it gives up the
    line's 30 pt), the sweep on dark artwork, pulling down from the dial.
- **Colour fills in as you listen** (Paul, 22 Nov 2026: "1 and 3 is a
  good call", from the identity mock-ups):
  - I1: Up next tab cards and the big first card show their artwork in
    black and white until the episode is started; the colour wipes in
    from the left as far as you've listened (live for the one playing).
    The island's round artwork sweeps in with its ring
    (`DeckColourFill`, `DeckWipeShape`, `DeckSweepShape` in DeckRing.swift;
    `DeckRingArtwork(sweep:)`; the player dial uses the same sweep).
  - I3: Your shows tiles are in colour only when the show has something
    new (with the coral "n NEW"); caught-up shows are black and white and
    a little quieter (`DeckShowTile.art`).
  - Check on the phone: a whole Up next of untouched episodes looks grey
    (that's the idea, but say if it's too dull), the coral NEW still reads.
- **Bottom bar: disc and pill** (Paul, 22 Nov 2026: "I quite like disc
  and pill", M3): the dark island is gone. Left, a 70 pt round disc: what's
  playing (or the top of Up next) with its ring and the colour sweeping
  in, play / pause on it; tap plays or pauses, touch and hold opens its
  tab (the hero card and its tab still open it too). Right, a white pill
  of words, Tabs · n / Shows / Find, the page showing in an ink capsule;
  swipes along / up it as before (`DeckBarDisc`, `DeckBarWords` in
  DeckTabsBar.swift; bar 70 pt).
- **Player: big time with chapter and time-left pills** (Paul, 22 Nov
  2026: "v1 with the chapter and ends from v2 but instead of end time
  it's remaining time", from the V1–V3 boards on the finishing-touches
  page). Both players, while listening: under the title the time played
  big (Outfit 60 heavy), then two pills: the chapter ("2/5 · Comfort
  darts", tap for chapters; "No chapters · Make them ›" or Skip ad as
  before) and "57m left" at your speed (the drag's "Half speed" while
  scrubbing) (`DeckBigReadout`, `DeckChapterRow(compact:)`). Then the
  line, then deck keys: the skips as soft square keys, play in a ring
  that fills as you listen (`DeckPlayerTransport`). The ‹ › chapter
  arrows and the small times row are gone while listening (chapters skip
  from the chapters sheet, headphones and the lock screen); Read along
  keeps its chapter row and small times under the line.
- **Big Up next card the height of the others** (Paul, 22 Nov 2026:
  "keep it wide but make it the same height as the other cards"): the
  first card is still full width but as tall as a three-across tab
  (`DeckTabsGrid.cardHeight(forWidth:)`): words on the left (PLAYING NOW /
  PAUSED / UP FIRST, show, title on two lines, progress with time and
  time left), square artwork on the right fading into the show's colour,
  a 50 pt white play key over the artwork's corner. Same swipes and hold.

## Done in build 175 (22 Nov 2026, PR #93; Paul: "Build")

- **After build 174** (Paul, 22 Nov 2026, screenshots of the 606 tab
  page and the readout):
  - No ring round the play key (`DeckPlayerTransport`).
  - No knob on the dial's ring ("makes you think you can click it"); the
    dial is only for looking (`DeckDialRing.draw`).
  - A tab that isn't playing ("NEXT IN UP NEXT") was still the old
    layout (small times row, round dim skips): now the same as the live
    page: its saved place big and faded, one pill ("Not started · 1h
    17m" or "54m left"), its progress as a still line, the square skip
    keys dimmed and the white Play (`DeckTabRestingReadout`,
    `DeckTabRestingLine`, `DeckTabRestingTransport`).
- **Bar: swipe the disc up for the player** (Paul, 22 Nov 2026: G3):
  tap still plays / pauses; a quick upward swipe on the disc (or touch
  and hold) opens what's playing; a small handle sits above the disc
  while something's on (`DeckBarDisc`).
- **Readout T1** (Paul, 22 Nov 2026): the big time, a small "54m left"
  pill under it, then the chapter on its own as a full-width bar with
  ‹ › at its ends (`DeckBigReadout`, `DeckChapterRow(wide:)`); the resting
  tab page's pill is the same small size.
- **Asked, mocked, waiting on Paul** (bottom of
  https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3):
  - No way to the player from the bar now (the disc only plays /
    pauses, hold opens): G1 tap the disc opens, a small white play key
    on its edge; G2 "Now" as the pill's first word; G3 swipe the disc up
    (Apple Music style); G4 a slim title strip above the bar.
  - Chapter on its own, full width; time left near the time: T1 small
    "54m left" pill under the time, chapter bar with ‹ › full width; T2
    "−54:12" pill beside the time; T3 time left as quiet words, chapter
    bar without arrows.
  - Up next ("have I ruined it with the bigger card?"): with cards K1
    even three-across grid, Now outlined (no big card), K2 wide row cards
    (playing one in its colour), K3 two across with Now spanning the row;
    without cards L1 plain list with round artwork and hairlines, L2 big
    numbers and show-colour dots, L3 artwork mosaic with words under.
    **Paul: G3, T1** (22 Nov 2026, built above); Up next: K1, K2 and L2
    the strongest; asked whether L2 works with Your shows as cards, and
    to see Your shows done in a similar (not identical) way.
    Told him: L2 with today's artwork tiles for Your shows would feel
    like two apps. Mocked, last row of the same page: L2 beside S-L2a
    (Your shows as a running list: big numbers for Top shows, colour
    dot, show name, "2 NEW" / Caught up, small artwork on the right) and
    S-L2b (colour blocks two across, the show's colour and name, no
    artwork, grey when caught up). **Paul: L2 + S-L2a** ("Yea let's go
    for it", 22 Nov 2026), built:
    - Up next (tabs mode): the big first card stays; under THEN the rest
      are a cardless running order, one row each (`DeckTabsGrid(rows:
      true)`, `DeckTabRow`, 92 pt): a big order number (ink once
      started, pale grey #C9C4BA until then), the title in Outfit 18
      heavy with two lines' room, then a dot in the show's colour (NEW
      pill when fresh) and "Show · 9 Nov · 52m"; hairlines, no artwork,
      no ×. Same touches as the tiles: tap opens, swipe left Played,
      right Play next / Add to end, hold and drag to reorder (the slot
      maths now works for one column too), still hold for the menu. The
      "Find something" tile is a short dashed row at the end.
    - Your shows (tabs mode): a running list (`DeckAllShowsRow(list:
      true)`, `DeckShowLine`): big rank number for Top shows (a faint ·
      for the others), the show's colour dot and name in big type, where
      new episodes go and a coral "2 NEW" or "Caught up", 48 pt artwork
      on the right (black and white when caught up), hairlines; sort key
      as before. Card deck mode keeps the tiles.
    - Check on the phone: swipe distances on a full-width row (they're a
      share of the row's width, so longer than on the tiles), dragging a
      row, long show names.

## Done in build 176 (22 Nov 2026, PR #94; Paul: "Build")

- **Back to the cards** (Paul, 22 Nov 2026, after build 175: "I prefer
  the old look with the cards before I added the big card. So both your
  shows and up next go back to the smaller card views"). Tabs mode:
  - Up next is the two-across full-colour tab cards again, as in builds
    162–171: every episode a card (1.25 × its width), "Now" on the one
    playing first, then 1, 2, 3…; card text back to its two-across sizes.
    No big first card, no "THEN", no running-order rows. Kept from later
    builds: colour fills in as you listen (I1), the dashed "Find
    something" tile as the last card, the disc and pill bar.
  - Your shows is the two-across artwork tiles again (black and white
    when caught up, coral "n NEW").
  - The big card (`DeckTabsHero`, `DeckTabsHeroCell`), the L2 rows
    (`DeckTabsGrid(rows:)`, `DeckTabRow`) and the S-L2a list
    (`DeckAllShowsRow(list:)`, `DeckShowLine`) stay in the code, unused,
    in case Paul wants them back.

- **Player G3: Apple-style artwork, blurred backdrop, colour creeps in**
  (Paul, 22 Nov 2026: "is there another design for the dial that uses
  the space across?", then "more like apple podcast with the artwork in
  the middle and the background … blur … dropping the ring", then "the
  colour sweep line isn't such a line. More of a colour creep", picked
  G3 from https://claude.ai/artifact/NN8buzwaa8vmcJAntVSsZq, options A
  square frame, B wide pill, C gauge, D record and sleeve, E wide
  rectangle, F edge-to-edge, G / G2 / G3 Apple style). Both players
  (the tab page and the card-deck player):
  - No ring round the artwork: it's a big rounded square in the middle
    (screen width less 56 pt where the height allows; `DeckDialGeometry.
    artwork` = the whole spot, `corner`), with a soft shadow. Progress is
    the line above the keys. Tapping it still turns it over to the words
    (now a rounded square too); the search pill stays, its dots went with
    the ring. Read along's corner picture is a small rounded square.
  - Behind the whole player, the artwork blurred and darkened over the
    show's colour (`DeckPlayerBackground(artwork:)`, `DeckBlurredArtwork`:
    blurred once per artwork into a 96 pt picture off the main thread,
    kept in memory, so nothing blurs live).
  - The colour creeps in with no line, everywhere it fills in
    (Paul: "can the colour creep also apply on any other effects like
    this"): a wide soft, slightly tilted fade on square artwork
    (`DeckSoftWipe`: the player, a resting tab's page, Up next tab cards)
    and a soft fade round the turn on round artwork (`DeckSoftSweep`: the
    bar's disc and other ringed artwork). `DeckWipeShape` /
    `DeckSweepShape` are no longer used.
  - Check on the phone: the blur on pale and dark artwork, the creep on
    a just-started episode (barely any colour yet), the artwork size on a
    small iPhone.

## Done in build 177 (23 Nov 2026, PR #95; Paul: "Build")

- **Artwork in full colour again** (Paul, 23 Nov 2026: "remove the
  artwork colouring progress as I like seeing the artwork in its full
  glory on the up next page. Keeping shows without episodes black and
  white. Also the player colour fade goes too"): Up next tab cards, the
  bar's disc, ringed artwork, a resting tab's page and the player's
  artwork are always in full colour (`DeckColourFill` now just draws the
  picture; the player dial's artwork too). Your shows tiles stay black
  and white when caught up (I3). `DeckSoftWipe` / `DeckSoftSweep` stay in
  the code, unused. The blurred backdrop behind the player stays.

## Done in build 178 (24 Nov 2026, PR #96; Paul: "Build")

- **No-chapters bar** (Paul, 23 Nov 2026, build 177 screenshot:
  "Chapter pill looking odd": an outlined "No chapters · Make them ›"
  pill sat inside the filled full-width chapter bar). With no chapters
  the bar itself is the faint outline and the words sit in it, no second
  pill (`DeckChapterRow.wideBackground`).

## Done in build 179 (25 Nov 2026, PR #97; Paul: "Yes")

Paul, 25 Nov 2026, on the loose-ends list: "1, ok update / 2, mark on
the line / 3, tidy em up / 4, how do I run it / 5, and you'll remind of
this on dec 1?".
- **Widgets in the Deck look** (`Widgets/PoddeckWidgets.swift`,
  `DeckPalette` day / night, `DeckType.outfit`): warm page, white card
  on medium / large, artwork with rounded corners, coral "PLAYING", ink
  round play key, thin ink progress line, Outfit type (the font files are
  bundled into the widget too: project.yml PoddeckWidgets resources +
  `UIAppFonts` in Config/Widgets-Info.plist; falls back to SF if not);
  Deck night when the iPhone is dark. Same widgets, sizes and keys.
- **Search hits on the progress line**: a phrase opened from Find's
  "Said in your episodes" shows as small yellow dots just above the
  player's line (`DeckPlayerLine.drawHits`, from `DeckDialSearch.lineHits`,
  set by `DeckPlayerDial`); the pill with the count stays.
- **Screenshots job** run by hand for the first time (25 Nov, on the
  branch); Paul can run it from Actions → Screenshots → Run workflow.
- **1 Dec reminder** set (scheduled task, 9am UK): repo back to private,
  and ask Paul about one GitHub Mac build to see if Codemagic can stop.
- Tidy-up, below.

### Tidy-up: card deck mode gone

- **Tabs only** (Paul chose to stay with Tabs): Settings → Look no longer
  has "Up next as" or Layout; the "deckHome" / "deckLayout" settings are
  no longer read (an old "deck" choice just opens Tabs). Deleted with it:
  the card-deck Up next (`DeckUpNext*.swift`: top card, stack, fan),
  `DeckLayout*.swift`, the card-deck player `DeckPlayer.swift`
  (`DeckPlayerView`; its backdrop moved to `DeckPlayerBackground.swift`,
  with `bottomColour` / `morph`), the Shows tab's show cards, catch-up and
  New sheet (`DeckShowsNew.swift`, `DeckShowStack`…), `DeckTabPill` and
  the card-deck mini player. Kept and moved to `DeckQueue.swift`:
  `deckSelectTab`, `DeckMark`, `DeckQueuePlan`, `DeckQueueMoves`,
  `DeckUpNextTime`. Anything that asked for the player still opens the
  playing episode's tab. Demo mode / Screenshots lost the "carddeck" screen.
- Unused code removed, no visible change: the big first Up next card
  (`DeckTabsHero.swift`) and L2 rows, the S-L2a Your shows list, the colour
  creep pieces (`DeckColourFill`, `DeckSoftWipe`…), the dial's ring drawing
  and drag code (`DeckDialRing`), the old island / Safari bar pieces in
  DeckTabsBar.swift (`DeckIslandNow`, `DeckTabsBarNow`…, not
  `DeckTabGroupPill`, kept on purpose). Ads code untouched.

## Done in build 180 (25 Nov 2026, PR #98; Paul: "Build when ready")

- **Swiping the playing tab away doesn't start the next one** (Paul,
  25 Nov 2026: swiped the episode playing away as played and the next
  in the queue played by itself; then: "If the current one was playing
  when swiped away, then I'd like it to auto play"). Marking it played
  by hand (`PlayerModel.finishEarly`): if it was playing, the next one
  starts; if it was paused, the next one loads ready, paused. An episode
  reaching its end (or the show's outro skip) carries on as before.
- **Rewind amounts you can set** (Paul, 25 Nov 2026: "let people set
  those like the skip back and forth buttons"): under "Rewind a little
  when you resume" in Settings → Playback, three choices while it's on:
  after a short pause 2 / 3 / 5 / 10 s (default 3), after a minute or
  more 5 / 10 / 15 / 20 / 30 s (default 10), after an hour or more
  10 / 20 / 30 / 45 / 60 s (default 20). Synced as "rewindShort",
  "rewindMinute", "rewindHour" (`RewindAmounts` in PlayerModel.swift).
- **No ⋯ on the player** (Paul, 25 Nov 2026: "it does the same thing
  clicking on the show name does"): the open tab's top row is ⌄ and the
  label (kept centred); `DeckTabMoreSheet` is gone. Play next / Remove
  from Up next stay on the tab's hold menu and the "This episode" card;
  the show name opens the show.
- **Skip keys without boxes** (Paul, 25 Nov 2026: "remove the rounded
  edge boxes on the skip back and forward buttons"): plain skip icons
  either side of play, on the live player and a resting tab's page
  (`DeckPlayerTransport`, `DeckTabRestingTransport`); same size and
  touch area (58 pt).

## Done in build 181 (27 Nov 2026, PR #99; Paul: "build")

- **Player R2 "Plain and big"** (Paul, 27 Nov 2026: "Regular r2 still",
  from https://claude.ai/artifact/JMXV4axyWg2L9h8V8VDmL2). The tab page
  while listening: the artwork as wide as the text (page width less
  48 pt, edges lined up with the title and line), show and title
  left-aligned under it, the progress line, then one times row under the
  line: played · the chapter now with › (tap for the chapters sheet;
  "ends 21:42" when there are no chapters, still opening the sheet with
  Make chapters) · −left at your speed; then skip / play / skip, volume
  on tall screens, Options · Read along · AirPlay. The big time
  (`DeckBigReadout`, deleted) and the full-width chapter bar are gone
  while listening; Read along keeps its chapter row above the line and
  the same times row, shrunk (`DeckDialTimes(openChapters:)`). A tab
  that isn't playing has the same layout: its still line and a quiet
  times row (saved place · Not started / Carry on · −left,
  `DeckTabRestingTimes`, replacing `DeckTabRestingReadout`).
- **Bar B1: mini player card over icon tabs** (Paul, 27 Nov 2026: "B1",
  from https://claude.ai/artifact/94LKhvKijV5iefrskQ6zUV). The disc and
  pill are gone. A white card (58 pt, radius 18, soft shadow) floats above
  the tabs: 40 pt artwork, title, "Show · 54m left" at your speed, play /
  pause and skip forward, a thin ink progress line along its foot. Tap
  the card (or swipe it up) for the playing episode's tab. With nothing
  on it shows the top of Up next ("Up next · Show · 26m", or "Carry on ·
  12m left"; tap or play starts it); with Up next empty, "Up next is
  empty · Find something ›" (tap goes to Find). Under it a strip of three
  icons with labels, Tabs · n / Shows / Find, the page showing in ink;
  tapping the page already showing still goes back to its first screen,
  swipe up on the strip for the tab overview, along it for the page
  before / after (`DeckMiniCard`, `DeckBarIcons` in DeckTabsBar.swift;
  bar 114 pt, the lists' bottom room and the fade grow with it).

## Done in build 182 (27 Nov 2026, PR #100; Paul: "when the compile check finishes, build it")

- **Skip back on the mini player** (Paul, 27 Nov 2026: "can we add a
  skip back to the mini player"): the B1 card's keys are skip back ·
  play / pause · skip forward, using your skip lengths; the skips are
  dimmed with nothing playing (`DeckMiniCard.keys`).

## Done in build 183 (27 Nov 2026, PR #101; Paul: "Build")

- **Mini player fixes** (Paul, 27 Nov 2026, build 182 screenshot of Your
  shows; "menu see through and not going to bottom"): the Tabs · Shows ·
  Find icons had only a see-through fade behind them, so the show tiles
  scrolled through under them; now the page colour is solid from the
  card's middle all the way down under the home indicator to the screen's
  edge (28 pt fade above it) (`DeckRoot.bottomFade`). "Show · 1h 2m left" cut off as "Elis
  James and John Robins · 1…": the show's name now gives way first, so the
  time left always shows (`DeckMiniCardLeft`). The progress line's ends
  were cut by the card's rounded corners: it's now a rounded 3 pt line
  inset 16 pt from the sides, 4 pt up from the foot
  (`DeckMiniProgressLine`).

## Done in build 184 (27 Nov 2026, PR #102; Paul: "Build")

- **Option C: two pages, pull down to search** (Paul, 27 Nov 2026: "Yes
  let's build it", from https://claude.ai/artifact/9pjRqhQGZ5Fd2BZf9CKfCW
  C1–C4). The Tabs · Shows · Find strip at the bottom is gone; the bar is
  just the B1 mini player (`DeckTabsBar`, height = the card).
  - Both pages open with the same top (`DeckPageTop` in
    `App/DeckPageTop.swift`): the Poddeck mark and Settings gear, and a
    search box "Search, or pull down".
  - Switching pages (Paul, 27 Nov 2026: "swipe on mini player", D):
    drag the mini player sideways, left for Your shows, right for Up
    next (it follows the finger a little; past 40 pt or a flick); two
    small dots under it show the page and can be tapped (`DeckPageDots`,
    `DeckMiniCard.flip`). Tap still opens the player, swipe up too. A
    switch at the top was built first and dropped for reach.
  - Pull either page down past its top (90 pt, finger still on the page)
    and the search drops in with the keyboard up (`deckPullToSearch`); the
    pull also checks for new episodes, at most every 2 minutes, as pull to
    refresh did (that's gone). The search is the Find page with Cancel
    beside its box, going back to the page it came from
    (`DeckRoot.openSearch` / `closeSearch`, `\.deckOpenSearch`). Results as
    before: Your shows, Episodes, Said in your episodes, New shows; nothing
    typed: recent searches, New to you, the chart.
  - Up next: under the top, "Up next" and "8 · done by 23:10", then the
    tabs.
  - Your shows: "Your shows" heading with Discover ↓ (scrolls down), ⇅
    and + (opens the search, which takes pasted links); the tiles; then
    Discover underneath (`DeckDiscoverSection` in DeckFind.swift, shared
    with the empty search): New to you, the UK chart with categories and
    Follow, and "Paste a show's link". Show previews open on this page.
  - Not done: swiping sideways across the whole page (the Up next cards'
    own swipes, Played / Play next, would fight it).
    Check on the phone: the pull distance, pull vs scrolling back to the
    top quickly, the keyboard coming up, Cancel, Discover on a long list,
    the mini player's sideways drag vs its taps and swipe up.
  - **Switch out of reach at the top** (Paul, 27 Nov 2026: "how can we
    make it easier to switch … for reachability"). Mock-ups
    https://claude.ai/artifact/1dNa6zA1gtbdmsiUHHM4BE: A as built (top),
    B a floating Up next | Your shows pill just above the mini player
    (suggested), C two words under the mini player, D just swipe the mini
    player (dots under it); in B–D dragging the mini player sideways also
    flips pages. **Paul: D** (27 Nov 2026), built above.

## On the branch for build 185 (27 Nov 2026; not built yet)

- **Pill back at the top, no search box** (Paul, 27 Nov 2026, on build
  184: "I thought we were going to leave the pill at the top so you could
  also switch between the two tabs like that, and also the search is
  hidden until you pull down"). The Up next · n | Your shows · n pill is
  back under the Poddeck mark on both pages (`DeckPageSwitch`, tap a
  side or swipe along it; tapping the side showing goes back to its first
  screen), as well as dragging the mini player sideways and its dots.
  The "Search, or pull down" box is gone: the search opens only by
  pulling a page down (or Your shows' +, and "Find something" / "Paste a
  show's link"). Up next's line under the pill is "8 episodes · done by
  23:10" (the separate "Up next" title went, the pill says it).
- **Mini player swipe jittered going left** (Paul, 27 Nov 2026): the
  drag was measured in the card's own space while the card moved with the
  finger, so each movement counted twice (as the show page swipes once
  did); now measured against the screen, and the card springs back only
  when you let go (`DeckMiniCard`, `slide`).

## Finishing touches: looks to choose from (21 Nov 2026)

- Paul (21 Nov 2026): happy with how everything works; wants a few
  different looks for Up next and the bottom bar, as a final beautiful
  touch. Mock-ups: https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3
  (today's look first in each row). Up next: U1 now playing hero (the
  playing episode as one big card with progress and play, the rest three
  across with start times; the bar keeps only the words), U2 evening
  timeline (start times down a line, wide cards), U3 fanned tab stack
  (Safari-style overlapping cards), U4 white label cards (artwork inside
  a white card with the title on white, like a cassette label). Bar: B1
  two floating pills (dark mini player + small word pill), B2 bar in the
  show's colour with progress along its top edge, B3 a raised ring in
  the middle (play / pause) with Tabs · Shows · Find · Settings round
  it, B4 one slim dark island (ring, title, three icon keys). Paul (21
  Nov 2026): not U4; U2 nice but no timetable pressure; B1 or B4 could
  work. Both drawn over his real Up next screenshot (Elis James and John
  Robins #594 playing, Straight Outta Cobham next), bottom row of the
  same page. Then (Paul: try the other U ideas with the real example;
  a timeline without start times): bottom row of the same page, with
  his two real episodes: U1 hero (words pill only), U3 fanned stack (B4
  island), U2 as an order rail (Now / Next dots on a line, the playing
  dot fills as you listen, "about 1h 56m of listening", no clock), and
  U2 as lengths on a tape (one bar across the top split by episode in
  each show's colour, each card with a length bar). Paul (21 Nov
  2026): likes U1 and U3 (fanned stack; he first wrote U2 by mistake),
  each with the one slim island; asked for a usable prototype of each
  (the U2 rail one stays on the page too). Two tappable boards at the foot
  of the same page (play / pause on the card and the island, progress
  runs 10× fast, tap another card to play it, mark played with a 6 s
  Undo, island icons switch Tabs / Your shows / Find, the tab count
  badge). **Paul picked U1 with the island** (21 Nov 2026): build 172.
- **Player one-handed** (Paul, 22 Nov 2026: dragging round the dial is
  hard one-handed; move progress elsewhere, e.g. artwork going from
  black and white to colour, or scrap the ring?). Suggested: keep the
  ring to look at only (progress, chapters, search dots; tap still turns
  it to the words) and scrub with a straight line in the thumb zone just
  above skip / play / skip (same drag rules as the old line); the colour
  sweep only as a finish on top, not as the scrubber. Three playable
  boards at the foot of https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3
  (1 ring to look at + line, 2 the same with the artwork's colour
  sweeping in, 3 no ring, just the line). **Paul picked 2** (22 Nov
  2026); see build 174.
- **Identity** (Paul, 22 Nov 2026: "Have we lost some identity … just
  another podcast app"). Told him: the ring, tabs and the show's colour
  are the Poddeck bits; the island and the player's lower half are
  generic. Suggested "colour fills in as you listen" as the thread.
  Mock-ups at the foot of https://claude.ai/artifact/TSVxvEeZb6HWKVbH3xN4X3
  (tap play): mini I1 tabs black and white until started, colour wipes
  in with progress, island artwork sweeps too; mini I2 player with a big
  time readout, chapter-cut line with a ring knob, square deck keys and a
  ring round play; mini I3 Your shows in colour only when there's
  something new; major I4 Up next as records (big disc for what's on,
  the queue as a shelf of discs that fill with colour). **Paul: I1 + I3**
  (22 Nov 2026), in build 174; asked for more player display and menu
  bar options.
  More options on the same page: player Q1 the line being said under the
  title, Q2 info strip (chapter, ends, speed, sleep), Q3 edge to edge
  (no ring, the whole picture fills with colour), Q4 tape-deck counter;
  bars M1 today's island with the sweep, M2 the island itself fills in
  the show's colour, M3 a big play disc + a word pill, M4 full-width bar
  with a colour line along the top. **Paul: M3 disc and pill**; for the
  player, V1 with V2's pills (time left instead of ends): build 174.

## Queued for the next app build

- **Player page rejig?** (Paul, 26 Nov 2026: "Mock ups to rejig the
  player page?"). Six layouts drawn with #594 on
  https://claude.ai/artifact/JMXV4axyWg2L9h8V8VDmL2: Now (build 180),
  R1 Thumb deck (smaller artwork, no big time, times at the line's ends,
  everything pressed in the lower half), R2 Plain and big (Apple-style
  wide artwork, title left, chapter as quiet text under the line), R3
  Counter and chapters (small artwork beside the title, big counter,
  this chapter + next two as rows), R4 Words under the art (the line
  being said under the title, tap for Read along), R5 Live chips and Up
  next (Options as chips showing what's on, the next episode at the
  foot). Suggested R1 with R5's chips. **Paul: "R2 probably best. Any
  other suggestions"** (26 Nov 2026). Four R2 variations added to the
  same page: R2a live chips (Read along · 1.2× / Trim / Sleep chips ·
  AirPlay as the bottom row), R2b one faint line of the words under the
  title (tap for Read along), R2c next episode at the foot instead of the
  volume and arrow, R2d artwork edge to edge fading into the backdrop.
  Suggested R2a with R2c's next-up card. **Paul: "Regular r2 still"**
  (27 Nov 2026): built, see build 181 below.

- **Mini player and bar rejig?** (Paul, 27 Nov 2026: "Let's look at
  reworking the mini player and bar too"). Six options over his Up next
  on https://claude.ai/artifact/94LKhvKijV5iefrskQ6zUV: Now (disc and
  pill), B1 floating white player card (artwork, title, show · time
  left, play, skip, progress along its foot) over a strip of three icon
  tabs, B2 the same card with the player's blurred-artwork backdrop and
  tabs as words, B3 one pill (round artwork with play, title + time
  left, three icons), B4 no player bar (what's playing is the first tab
  as round artwork with a ring), B5 slim one-line strip above a plain
  full-width tab bar. Suggested B1 (matches the R2 player). **Paul: B1**
  (27 Nov 2026): built into build 181, see above.

- **One page?** (Paul, 27 Nov 2026: "making the podcast app a bit of a
  one-pager where everything bar the main player is on one page"). Four
  ideas on https://claude.ai/artifact/RTki81tocYwdVrmetNYovt (each phone
  scrolls; no Tabs · Shows · Find strip, B1 mini player kept, the R2
  player stays its own screen): O1 Shelves (search at the top, then
  sideways rows: Up next tab cards, New this week, Your shows tiles, UK
  chart, Settings at the foot; suggested), O2 Up next first, the rest
  folded (today's Up next grid, then Your shows / Find / Settings as
  cards that open in place, jump chips stick to the top), O3 Search is
  home (big search box answers with the page; playing card, Then list,
  shows, chart), O4 Today like a newspaper (greeting, "3 new since this
  morning", Carry on headline card, Up next row, shows grid, one chart
  pick). Waiting on Paul.

- **Organising Up next and shows?** (Paul, 27 Nov 2026: loves the Up
  next artwork cards and the Shows tiles going black and white; "a way
  we haven't looked at yet … function and form", separate tabs fine).
  Five on https://claude.ai/artifact/9pjRqhQGZ5Fd2BZf9CKfCW (same cards
  and tiles in all): A The shelf (one tab: each show a tile with its
  waiting episodes stacked behind it, corner number = when its next one
  comes up, tap to spread into the episode cards; caught-up shows black
  and white at the end; bar Shelf · Find; suggested), B Lanes (a
  sideways row of cards per show, Top rank first), C Two pages you swipe
  between (Up next · Your shows switch, pull down to search, no tab
  strip), D Up next row on top with show tiles underneath as a filter,
  E Today's two tabs plus filter chips (All · Started · New ·
  Downloaded · Under 45m; runner-up).
  Paul: interested in C, asked how finding new shows works with it
  (27 Nov 2026). Worked through on the same page (C1–C4): pull down on
  either page = one search for everything (before typing: recent, New to
  you, chart; typing: Your shows / Episodes / Said in your episodes / New
  shows with Follow); browsing lives at the foot of Your shows (New to
  you, UK chart with categories, Paste a show's link; "Discover ↓" jumps
  there); a new show opens its page over the search (Follow, or Play
  next / Add to end to try it). Alternative offered: a third swipe page,
  Discover. **Paul: "Yes let's build it"** (27 Nov 2026): on the branch
  for build 184, see above.

- **Codemagic is pay as you go** (Paul, 19 Nov 2026: put a card on it so
  builds run again). Told him: roughly $0.095 a Mac minute, a build ~5
  minutes, so about 50p a build (estimate; Codemagic's pricing page has
  the real figures). Keep batching changes into fewer builds.

- Nothing queued. Still waiting on Paul: where he tried Undo and saw
  nothing (old); other iPhone sizes not checked; feeds with a username
  and password: later. The website refresh (Deck screenshots, drop the
  "Ad breaks" card, real support address) is Paul's own task in another
  session (17 Nov 2026). Old ideas cleared (Paul, 17 Nov 2026: sandier
  app, the undecided "not like Apple" touches, the font notes, New
  Episodes and player layout option rounds, the Cloudflare alerts
  backup): all overtaken by the Deck look.

- **"Anything missing?"** (Paul, 25 Nov 2026: "I think we're in a good
  spot"). Told him the loose ends, waiting on his pick: 1 widgets and
  Lock Screen widgets still in the old Tape Deck look (green display,
  orange, mono type: `Widgets/PoddeckWidgets.swift`), not Deck; 2 the
  player's search pill counts hits that no longer show anywhere (the
  dots went with the ring in 176): mark them on the progress line or
  drop the pill; 3 tidy-up build: delete the unused pieces (big card,
  L2 rows, S-L2a list, soft creep, the ring drawing, ad-finding code,
  maybe Card deck mode) so fewer places can break; 4 run the free
  simulator screenshots job once while the repo is public (before
  1 Dec); 5 1 Dec: repo back to private, and try one free GitHub Mac
  build to see if paid Codemagic can stop; 6 checks only Paul can do:
  CarPlay with the new player, a smaller iPhone, Deck night.

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
  Tips on the website (Paul asked 18 Nov 2026 if a tip jar would make
  him "commercial"): told him it's a grey area for Apple's EU trader
  question (any money tied to the app may count; answer it honestly, or
  hold tips until after the store listing is settled); keep the tip
  link on poddeck.uk only, never in the app (a tip button or link in
  the app would have to go through Apple's in-app purchase, Apple takes
  a cut); UK tax: casual gifts are usually not trading income, and the
  £1,000 trading allowance covers small amounts; tip sites take a fee
  per tip (Ko-fi / Buy Me a Coffee plus card fees). Not legal or tax
  advice; nothing decided.

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
