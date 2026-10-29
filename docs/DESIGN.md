# Design spec

Minimal, calm and functional, inspired by the Claude app. The reference
mockups are the `.dc.html` files in `/design` (one per screen, 390×844 phone
frames). They are layout references, not runnable pages: they rely on the
design canvas runtime. Build the SwiftUI screens to match them.

## Look

| Token | Value | Use |
|---|---|---|
| Background | `#FAF8F3` | Every screen |
| Surface | `#F1EEE6` | Search fields, segmented controls, mini player, quote card |
| Hairline | `#E8E3D8` | Row separators, tab bar top border |
| Control border | `#D9D4C7` | Outline buttons, toggle off |
| Ink | `#1F1E1B` | Text, primary buttons, play button |
| Muted text | `#6B675E` | Secondary text (passes 4.5:1 on background) |
| Accent fill | `#AD5230` | Toggles on, clip selection (white text passes) |
| Accent text | `#A4512F` | Text links and accent labels |
| Highlight | `#F3E3C6` | Search match highlight, new-episode row |
| Ad marker | `#D9A441` | Ad segments on the scrubber |

Show artwork placeholders use muted tones: `#4A5D73`, `#4F6B5A`, `#7A5368`,
`#8A6A3F`, `#5B5750`, `#6A5E86`.

**Type:** headings in a serif (mockups use Newsreader; New York, the iOS
system serif, is a good native choice). Body and UI in the system sans
(SF Pro). Transcript text in the serif at 18pt (current line 21pt).
Screen titles 34pt (tab screens) or 26pt (pushed screens).

**Shape and spacing:** 20–24pt side margins; list rows separated by hairlines
rather than cards; radii 10 (artwork, fields), 14 (mini player, buttons),
20 (large artwork). Touch targets at least 44pt.

**Icons:** thin line icons (SF Symbols at regular weight). No emoji.

**Avoid:** gradients, heavy cards, badge clutter, bright colours.

## Navigation

Tab bar: **Up Next · Library · Discover · Search**. Settings for shows
(auto-add, notifications, refresh) open from the sliders icon on Up Next.
The player opens from the mini player.

## Screens

1. **Up Next** (`design/Main.dc.html`): title, sliders and search icons;
   "Checked 2 hours ago · tap or pull to check now" line; episode count and
   total time; rows of artwork, show, title, meta (length · source · transcript
   status) and a reorder handle; "Keep playing new episodes" toggle; mini player
   with back 10 / play-pause / forward 10 buttons; tab bar.
2. **Now Playing** (`design/NowPlaying.dc.html`): themed to the artwork
   (background colour from the artwork, light text); grabber to close, large episode
   artwork, serif title, show name, current chapter link, scrubber with ad
   segments and "Ad skipped at …", back 10 / play-pause / forward 10, a single
   segmented row (speed · Trim · Boost · Sleep), Trim silences / Boost voices chips;
   bottom row Transcript · Play on (device picker sheet) · Up Next.
3. **Transcript** (`design/Transcript.dc.html`): timestamp headings
   (e.g. "1m 20s") with speaker-labelled lines beneath (Speaker 1 in ink,
   Speaker 2 in accent text), "Name speakers" button in the header, music rows
   with a music-note icon, past lines muted, current line larger, tap to select; selection actions
   Share clip / Copy / Bookmark; ad break shown as a dashed band with
   Show and "Not an ad?"; footer with play, time and "Follow along".
4. **Search** (`design/Search.dc.html`): search field; tabs Transcripts / Shows /
   My clips; results show episode, quote with highlighted match, "Play from
   mm:ss" and "Add to Up Next".
5. **Share a clip** (`design/Clip.dc.html`): quote card, length waveform with
   −5 / +5 sec, toggles (audio, link to moment, video card), Share button.
6. **Shows** (`design/AutoAdd.dc.html`): explanation of the ordering rule;
   "Top, in priority order" ranked list; "Skip buttons" back and forward lengths (5/10/15/30/60s); (rank number, move up, drag handle);
   "All shows" with a per-show row with notification bell and Off / Top / Bottom; "Checking for
   new episodes" with Hourly / Every 3 hours / Every 6 hours; toggles for
   Wi-Fi-only downloads and "Keep each show in order".
7. **Chapters** (`design/Chapters.dc.html`): From the show / Auto-generated
   switch, rows with chapter artwork, title, start time and length; ad chapters
   marked skipped; current chapter marked Playing.
8. **Discover** (`design/Discover.dc.html`): search field; category chips;
   "Because you listen to …" carousel; "Top in the UK this week" list with
   Follow buttons.

Copy in the mockups (show names, episode titles, transcript lines) is
placeholder content.

9. **Library** (`design/Library.dc.html`): "New Episodes" carousel of large
   artwork-tinted cards (when, title, description, play pill with length,
   download, more), then a "Your shows" artwork grid.

Exception to the calm palette: the Now Playing screen and the new-episode cards
take their colours from each show's artwork.
