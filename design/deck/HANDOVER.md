# Poddeck "Deck": build notes

Paul picked this on 14 Nov 2026 ("I love it"). The clickable prototype is the
spec: `design/deck/poddeck-prototype.html` (also
https://claude.ai/artifact/CC3pxxR1XwBGtnp13xAdbB). When this file and the
prototype disagree, the prototype wins on look and behaviour; CLAUDE.md wins
on queue and feature rules. Every existing feature stays. `QueueEngine`'s
Up next ordering rules do not change.

Paul's answers (14 Nov 2026): carry on from the PR #72 branch (no separate
build first); the plain warm page, not the fog; app icon A "The deck";
build the Layout setting now (last).

## Tokens (in code: `Theme` when `Theme.isDeck`)

- Page #EEEBE5 (`Theme.background`), card white (`Theme.surface`), 1 pt edge
  #E5E1D9 (`Theme.cardEdge`), lines in cards #F0ECE5 (`Theme.cardLine`).
- Ink #1C1B1A (`Theme.ink`), muted #6B6862 (`Theme.muted`), faint #8B877F
  (`Theme.faint`).
- Radius 24-28 for big cards, 18-22 for rows. Top card shadow
  0 18 40 rgba(40,30,10,.16), lighter on others: `deckPlainCard(radius:lifted:)`
  in DeckRoot.swift.
- Playing row in lists: ink card (`Theme.playingCard`) with white text.
- No accent of its own: the show's artwork colour (`ArtworkColors`) for its
  play key, artwork blocks and new dots. Keys that are on are ink.
- Ads amber #FFD66B (`Theme.deckAd`) on progress lines and the Skip ad chip.
- Type: Outfit everywhere (`Theme.outfit(size, weight)`; `Theme.big`,
  `Theme.title`, `Theme.text`, `Theme.mono` already use it in Deck): titles
  .heavy (800, tracking -0.6 to -1), body .medium/.semibold, small labels
  .bold in capitals with +0.6 tracking.
- Player: full-screen gradient from the show's colour to its dark shade to
  #17161A, white text, white play key with an ink symbol.
- Icons: SF Symbols, line style, filled only for play / pause / AirPlay.
- Deck night (`.deckNight`) is the dark version of the same tokens; use
  the Theme tokens, never literal hex, so both work.

## Shell (done, DeckRoot.swift)

`DeckRoot` holds three pages (0 Up next `DeckUpNextView`, 1 Shows
`DeckShowsView`, 2 Find `DeckFindView`), the floating pill `DeckTabPill`,
and `DeckMiniPlayer` on Shows / Find. `\.deckOpenPlayer` opens the
full-screen player (`DeckPlayerView`, shown by RootView's fullScreenCover).
Lists get bottom room automatically (`contentMargins` on each page).
`Theme.isDeck` is on for the default AUTO (Deck light / Deck night).

## Rules

- No compiler here: GitHub's Intel check compiles PRs and times out on big
  SwiftUI expressions. Keep each `body` / builder small; split into
  functions / small views; give closures explicit types where long.
- Reuse existing parts rather than rewriting: `LibraryStore` (`playNext`,
  `playLast`, `markPlayed`, `markUnplayed`, `undoable`, `listChange`,
  `moveQueue`, `addBackCatalogue`, `revealInUpNext`, `revealShow`,
  `showSheet`, `notesEpisode`), `PlayerModel`, `PosterSwipe` /
  `SidewaysPan`, `EpisodeLights`, `HaarKeyWord`, `HaarReadAlong`,
  `HaarChaptersSheet`, `PlayerOptionsSheet`, `RoutePicker`,
  `SystemVolumeSlider`, `HaarFindView` pieces (`ChartHistory`,
  `HaarChartRow`), `ShowSettingsView`, `TopPriorityView`, `StorageView`,
  History / Stats views, `UndoBar`, `ArtworkColors`, `CachedImage`,
  `ArtworkView`.
- Explain in plain English in comments where a choice was Paul's.
