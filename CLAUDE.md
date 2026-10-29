# Podcast app — project brief

Read this first in every session. It records what Paul (the owner) has decided.
Keep it up to date when decisions change. Detailed look and screen specs are in
`docs/DESIGN.md`; the build and release pipeline is in `docs/SETUP.md`; the
original screen mockups are in `design/`.

## What this is

A personal iOS podcast app for Paul's own iPhone, delivered through TestFlight.
It combines the best parts of Apple Podcasts, Spotify, Pocket Casts and
Overcast. Goal: **minimal to look at, fully functional underneath**, with a
calm look inspired by the Claude app (warm off-white, serif headings, one
terracotta accent).

## Constraints

- **iOS only.** Native app in Swift and SwiftUI.
- **No Mac.** Paul has no personal Mac and must not use his work Mac. All
  building happens in the cloud: GitHub Actions (macOS runners) builds the app
  and uploads it to TestFlight. See `docs/SETUP.md`.
- **No server and no running costs.** All AI features run on the iPhone.
  Nothing calls Claude or any paid API at runtime.
- Paul is not a developer. Explain changes in plain English, keep the build
  green, and tell him when a new TestFlight build is ready to try.

## Features (decided)

### Up Next queue
- Manual queue with drag to reorder, plus "Play next" and "Play last" on any episode.
- **Auto-add per show**: each subscribed show is set to **Off**, **Top** or **Bottom**.
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
  Proposed defaults (confirm with Paul): delete straight away, with a setting
  to keep played downloads for 24 hours; episodes with bookmarks or clips keep
  their transcript but not the audio.
- "Keep playing new episodes" toggle: when the queue runs out, continue with new
  episodes from auto-add shows.
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
- **Themed to the artwork** (like Apple Podcasts): the full player uses a large
  episode artwork image and a background colour taken from that artwork
  (extract a dominant/average colour on device), with light text and controls
  tinted to match. Pick text colours that keep 4.5:1 contrast.
- **Choose where to play**: an AirPlay/route button in the player opens the
  system device picker (AirPods, speakers, TVs, car) via AVRoutePickerView; the
  player shows "Playing on …" when not on the phone.
- Variable speed (1.0–2.0×), **Trim silences** (Overcast-style Smart Speed),
  **Boost voices**, sleep timer.

### Library and new episode cards
- Library tab opens with a **New Episodes** carousel of large cards like Apple
  Podcasts: episode artwork on top, card tinted with the artwork's colour,
  "4h ago", title, one-line description, a play pill showing the length,
  a download button and a more menu. Below: "Your shows" grid.

### Transcripts (on device)
- Use the publisher's transcript when the feed provides one
  (`<podcast:transcript>`), otherwise **transcribe on the iPhone**.
- Transcription runs in the background, preferring charging + Wi-Fi.
- **Speakers**: identify who is speaking (on-device speaker separation, e.g. an
  open-source Core ML diarization model) and label each line "Speaker 1",
  "Speaker 2"… Use real names when the publisher's transcript has them; Paul
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
- Skip automatically, mark breaks on the scrubber and in the transcript, and
  offer **Play ad** and **Not an ad** so Paul can correct it.

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

### Discover
- Search for new shows (people, topics) using Apple's free podcast directory.
- Browse by category; "Because you listen to…" suggestions from shows in
  the same categories as ones Paul follows; UK top charts with Follow buttons.

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
- Target device: Paul's iPhone 17 Pro on iOS 27.2. Minimum iOS: 27 (personal
  app, one device). Check Apple's current docs for iOS 27 speech, audio and
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

- Done: Up Next ordering rules in `Packages/PodcastCore` (`QueueEngine`) with
  unit tests; SwiftUI app skeleton (`App/`, project generated from
  `project.yml` by XcodeGen) with tabs and an Up Next list driven by the real
  rules using sample data; GitHub Actions `Build` workflow (tests + unsigned
  simulator build) passing.
- Waiting on Paul: Apple Developer Program membership (name correction with
  Apple support in progress). Then add signing + the TestFlight upload job
  (see `docs/SETUP.md`) to finish step 1.
- Next without Apple: step 2 (subscriptions, feed parsing, episode list,
  basic playback).

## Open questions for Paul

- App name and icon.
- Importing existing subscriptions (OPML export from his current app).
