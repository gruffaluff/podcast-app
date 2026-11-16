import SwiftUI
import PodcastCore

// Under the player on a tab's page (DeckTabEpisodePage): the episode (its
// place in Up next, download, words, played, save for later, a Go to show
// row) and its notes, on the app's own page colour, rising over the
// player's colour like a sheet. The show's own settings stay on the show
// page (Paul, 16 Nov 2026: "drop all the 'This show' details from the
// episode player card and just keep it in the show settings tab … maybe
// just add one thing … which is a shortcut to the show").

struct DeckTabEpisodeBelow: View {
    let episode: PodcastEpisode
    /// Room under the notes: the home indicator and a little more.
    let bottomRoom: CGFloat
    let close: () -> Void
    /// Back up to the player with the words showing.
    let readAlong: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckTabEpisodeRows(episode: episode, close: close, readAlong: readAlong)
            EpisodeNotesText(episode: episode)
                .padding(.horizontal, 16)
                .padding(.top, 22)
        }
        .padding(.top, 8)
        .padding(.bottom, bottomRoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .top) { sheet }
        .normalColours()
    }

    /// Rounded at the top; runs on past the foot so a bounce never shows
    /// the player's colour under it.
    private var sheet: some View {
        UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
            .fill(Theme.background)
            .padding(.bottom, -800)
            .shadow(color: Color.black.opacity(0.18), radius: 16, y: -4)
    }
}

// MARK: - The episode

private struct DeckTabEpisodeRows: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    @AppStorage(SaveForLater.key) private var savedRaw: String = ""
    let episode: PodcastEpisode
    let close: () -> Void
    let readAlong: () -> Void
    @State private var confirmRemove = false

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        DeckSetGroup("This episode") {
            upNextRow
            DeckSetLine()
            downloadRow
            DeckSetLine()
            transcriptRow
            DeckSetLine()
            playedRow
            DeckSetLine()
            savedRow
            if let show = episode.podcast {
                DeckSetLine()
                DeckTabGoToShowRow(show: show)
            }
        }
        .alert("Remove the download?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { store.removeDownload(episode) }
        } message: {
            Text("It will stream instead, or you can download it again.")
        }
    }

    // MARK: Up next

    @ViewBuilder private var upNextRow: some View {
        if isOn {
            DeckSetRowLabel(icon: "play.circle", title: player.isPlaying ? "Playing now" : "Paused", chevron: nil)
        } else if let place = DeckTabPlace.place(of: episode, store: store, player: player) {
            row(icon: "rectangle.stack", title: DeckTabPlace.words(place), value: place > 1 ? "Play next" : nil) {
                if place > 1 { DeckQueueMoves(store: store, player: player).playNext(episode) }
            }
            .disabled(place == 1)
        } else {
            row(icon: "rectangle.stack.badge.plus", title: "Not in Up next", value: "Add") {
                withAnimation(LibraryStore.listChange) { store.playLast(episode) }
            }
        }
    }

    // MARK: Download

    @ViewBuilder private var downloadRow: some View {
        if let fraction = downloads.progress[episode.episodeID] {
            row(icon: "arrow.down.circle", title: "Downloading · \(Int(fraction * 100))%", value: "Stop") {
                store.removeDownload(episode)
            }
        } else if episode.downloadFile != nil {
            row(icon: "checkmark.circle", title: "Downloaded", value: "Remove") { confirmRemove = true }
        } else {
            row(icon: "arrow.down.circle", title: "Not downloaded", value: "Download") {
                downloads.download(episode)
            }
        }
    }

    // MARK: Words

    @ViewBuilder private var transcriptRow: some View {
        if episode.transcriptState == .ready {
            row(icon: "text.quote", title: "Words ready", value: "Read along", action: readAlong)
        } else if transcripts.isQueued(episode) {
            row(icon: "waveform", title: transcriptProgress, value: "Stop") { transcripts.stop(episode) }
        } else {
            row(icon: "text.quote", title: "No transcript yet", value: "Transcribe now") {
                transcripts.transcribeNow(episode)
            }
        }
    }

    private var transcriptProgress: String {
        let id: String = episode.episodeID
        if episode.transcriptState == .transcribing {
            return "Transcribing on this iPhone · \(Int((transcripts.progress[id] ?? 0) * 100))%"
        }
        if let fraction = downloads.progress[id] {
            return "Downloading first · \(Int(fraction * 100))%"
        }
        return "Waiting to transcribe"
    }

    // MARK: Played and saved

    private var playedRow: some View {
        let played: Bool = episode.played
        return row(icon: played ? "checkmark.circle.fill" : "checkmark.circle",
                   title: played ? "Played" : "Not played yet",
                   value: played ? "Mark unplayed" : "Mark played") {
            if episode.played {
                store.markUnplayed(episode)
            } else {
                // With Undo; in Up next and New the tab closes.
                DeckQueueMoves(store: store, player: player).played(episode)
            }
        }
    }

    private var savedRow: some View {
        let saved: Bool = SaveForLater.isSaved(episode.episodeID, in: savedRaw)
        return row(icon: saved ? "bookmark.fill" : "bookmark",
                   title: saved ? "Saved for later" : "Save for later",
                   value: saved ? "Remove" : "Save") {
            SaveForLater.toggle(episode.episodeID)
        }
    }

    private func row(icon: String, title: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DeckSetRowLabel(icon: icon, title: title, value: value, chevron: nil)
        }
        .buttonStyle(.plain)
        .accessibilityHint(value ?? "")
    }
}

// MARK: - Go to show

/// One row under Save for later: the show's artwork and name; opens its
/// Deck show page (its settings are there). A show only being tried opens
/// the same page, where Follow sits.
private struct DeckTabGoToShowRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DeckTabsModel.self) private var model
    let show: Podcast

    var body: some View {
        Button {
            DeckTabNavigation.openShow(show, store: store, model: model)
        } label: {
            HStack(spacing: 12) {
                ArtworkView(url: show.artworkURL, title: show.title, size: 26, radius: 7)
                    .frame(width: 26)
                DeckSetRowLabel(title: "Go to show", value: show.title, chevron: "chevron.right")
                    .padding(.leading, -16)
            }
            .padding(.leading, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to " + show.title)
        .accessibilityHint(show.isTried ? "Opens the show, where you can follow it" : "Opens the show and its settings")
    }
}

// MARK: - Slim bar

/// Pinned at the top once the player has scrolled away: artwork, title,
/// the time and play / pause. Tap it to go back up to the player.
struct DeckTabSlimBar: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    let colour: Color
    let tap: () -> Void

    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: tap) {
                HStack(spacing: 10) {
                    DeckTabRing(episode: episode, size: 40, lineWidth: 2.5, gap: 2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(episode.title)
                            .font(Theme.outfit(14, .bold))
                            .lineLimit(1)
                        DeckTabSlimTime(episode: episode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Back up to the player")
            playButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DeckPlayerBackground.shade(colour)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
        .foregroundStyle(Color.white)
    }

    private var playButton: some View {
        let on: Bool = isOn && player.isPlaying
        return Button {
            DeckTabActions(store: store, player: player, group: model.group).playNow(episode)
        } label: {
            Image(systemName: on ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DeckPlayerColours.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Pause" : "Play")
    }
}

/// "12:30 · −40:00" (live, following the clock), or the saved place.
private struct DeckTabSlimTime: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        Text(words)
            .font(Theme.outfit(12, .medium))
            .monospacedDigit()
            .opacity(0.75)
            .lineLimit(1)
    }

    private var words: String {
        if player.nowPlaying?.episodeID == episode.episodeID, player.duration > 0 {
            let left: TimeInterval = max(0, player.duration - player.currentTime)
            return TimeFormat.clock(player.currentTime) + " · −" + TimeFormat.clock(left / max(player.speed, 0.5))
        }
        guard let duration = episode.duration, duration > 0 else { return episode.showTitle }
        if episode.position > 30, !episode.played {
            return TimeFormat.clock(episode.position) + " · " + TimeFormat.length(max(0, duration - episode.position)) + " left"
        }
        return episode.showTitle + " · " + TimeFormat.length(duration)
    }
}
